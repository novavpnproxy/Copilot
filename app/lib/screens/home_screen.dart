import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

import '../models/vpn_server.dart';
import '../services/api_service.dart';
import '../services/connection_failover.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
import 'server_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _ConnectionUi { disconnected, connecting, connected, disconnecting, error }

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  final VpnService _vpn = VpnService();

  StreamSubscription<V2RayStatus>? _statusSubscription;
  _ConnectionUi _connection = _ConnectionUi.disconnected;
  VpnServer? _activeServer;
  VpnServer? _preferredServer;
  String _language = 'fa';
  String _duration = '00:00:00';
  String? _message;
  bool _busy = false;
  bool _failoverRunning = false;
  int _currentAttempt = 0;
  int _attemptCount = 0;

  bool get _fa => _language == 'fa';
  bool get _connected => _connection == _ConnectionUi.connected;

  @override
  void initState() {
    super.initState();
    _storage.readLanguage().then((language) {
      if (mounted) setState(() => _language = language);
    });
    _statusSubscription = _vpn.statusChanges.listen(_onEngineStatus);
    _onEngineStatus(_vpn.currentStatus);
  }

  void _onEngineStatus(V2RayStatus status) {
    if (!mounted) return;
    setState(() {
      switch (status.state.toUpperCase()) {
        case 'CONNECTED':
          _connection = _ConnectionUi.connected;
          _duration = status.duration;
          _message = null;
          break;
        case 'CONNECTING':
          _connection = _ConnectionUi.connecting;
          break;
        case 'DISCONNECTING':
          _connection = _ConnectionUi.disconnecting;
          break;
        case 'DISCONNECTED':
          if (!_failoverRunning || _connection == _ConnectionUi.disconnecting) {
            _connection = _ConnectionUi.disconnected;
            _duration = '00:00:00';
            _activeServer = null;
          }
          break;
        case 'ERROR':
          if (!_failoverRunning) {
            _connection = _ConnectionUi.error;
            _message = _fa
                ? 'موتور VPN اتصال را برقرار نکرد.'
                : 'VPN engine failed to connect.';
          }
          break;
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _api.close();
    super.dispose();
  }

  Future<void> _chooseServer() async {
    if (_busy || _connected) return;
    final selected = await Navigator.of(context).push<VpnServer>(
      MaterialPageRoute(
        builder: (_) => ServerListScreen(language: _language),
      ),
    );
    if (selected == null || !mounted) return;
    await _storage.writeServerId(selected.id);
    if (mounted) {
      setState(() {
        _preferredServer = selected;
        _message = null;
      });
    }
  }

  Future<void> _toggleConnection() async {
    if (_busy) return;
    if (_connected) {
      await _disconnect();
    } else {
      await _connectWithFallback();
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _connection = _ConnectionUi.disconnecting;
      _message = null;
    });
    try {
      await _vpn.disconnect();
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.disconnected;
          _activeServer = null;
          _duration = '00:00:00';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa ? 'قطع اتصال انجام نشد.' : 'Could not disconnect.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connectWithFallback() async {
    setState(() {
      _busy = true;
      _failoverRunning = true;
      _connection = _ConnectionUi.connecting;
      _message = _fa ? 'در حال دریافت فهرست سرورها…' : 'Loading available servers…';
      _currentAttempt = 0;
      _attemptCount = 0;
    });

    try {
      // Fresh metadata is fetched each time so owner changes need no APK update.
      final servers = await _api.fetchServers();
      if (!mounted) return;
      if (servers.isEmpty) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa
              ? 'در حال حاضر سرور فعالی وجود ندارد.'
              : 'No active servers are currently available.';
        });
        return;
      }

      final savedId = await _storage.readServerId();
      if (!mounted) return;
      final preferredId = _preferredServer?.id ?? savedId;
      final candidates = <VpnServer>[
        ...servers.where((server) => server.id == preferredId),
        ...servers.where((server) => server.id != preferredId),
      ];
      _attemptCount = candidates.length;

      final connectedServer = await connectWithFallback<VpnServer>(
        candidates: candidates,
        isFatal: (error) =>
            error is ApiException || error is VpnPermissionException,
        onAttempt: (server, index) {
          if (!mounted) return;
          setState(() {
            _currentAttempt = index + 1;
            _activeServer = server;
            _connection = _ConnectionUi.connecting;
            _message = index == 0
                ? (_fa ? 'در حال اتصال…' : 'Connecting…')
                : (_fa ? 'تلاش با سرور بعدی…' : 'Trying the next server…');
          });
        },
        attempt: (server) async {
          // Profile remains transient and is requested only for this attempt.
          final profile = await _api.fetchServerConfig(server.id);
          await _vpn.connect(profile: profile, remark: server.name);
        },
      );

      await _storage.writeServerId(connectedServer.id);
      if (mounted) {
        setState(() {
          _activeServer = connectedServer;
          _preferredServer = connectedServer;
          _connection = _ConnectionUi.connected;
          _message = null;
        });
      }
    } on VpnPermissionException {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.disconnected;
          _message = _fa ? 'مجوز VPN داده نشد.' : 'VPN permission was denied.';
        });
      }
    } on ApiException {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa
              ? 'دریافت امن پروفایل از سمت سرویس در دسترس نیست.'
              : 'Secure profile delivery is unavailable from the service.';
        });
      }
    } on AllCandidatesFailedException catch (error) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _activeServer = null;
          _message = _fa
              ? 'اتصال به هیچ‌یک از ${error.attemptedCount} سرور برقرار نشد.'
              : 'Could not connect to any of the ${error.attemptedCount} servers.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _activeServer = null;
          _message = _fa ? 'اتصال VPN برقرار نشد.' : 'VPN connection failed.';
        });
      }
    } finally {
      _failoverRunning = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _stateLabel => switch (_connection) {
        _ConnectionUi.disconnected => _fa ? 'قطع' : 'Disconnected',
        _ConnectionUi.connecting => _fa ? 'در حال اتصال' : 'Connecting',
        _ConnectionUi.connected => _fa ? 'متصل' : 'Connected',
        _ConnectionUi.disconnecting => _fa ? 'در حال قطع' : 'Disconnecting',
        _ConnectionUi.error => _fa ? 'خطا' : 'Error',
      };

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _fa ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text(
              'NOVA VPN',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
            actions: [
              IconButton(
                tooltip: _fa ? 'تنظیمات' : 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  final language = await _storage.readLanguage();
                  if (mounted) setState(() => _language = language);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_moon_outlined,
                        size: 82,
                        color: Color(0xFF35D0BA),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'JEYRAN GROUP',
                        style: TextStyle(color: Colors.white54, letterSpacing: 2),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        color: const Color(0xFF101A2B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                _stateLabel,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _connected
                                      ? const Color(0xFF35D0BA)
                                      : Colors.white70,
                                ),
                              ),
                              if (_connected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 7),
                                  child: Text(
                                    _duration,
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: 132,
                                height: 132,
                                child: OutlinedButton(
                                  onPressed: _busy ? null : _toggleConnection,
                                  style: OutlinedButton.styleFrom(
                                    shape: const CircleBorder(),
                                    side: const BorderSide(
                                      color: Color(0xFF35D0BA),
                                      width: 2,
                                    ),
                                    backgroundColor: const Color(0xFF35D0BA)
                                        .withValues(alpha: .07),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : Icon(
                                          _connected
                                              ? Icons.stop_rounded
                                              : Icons.power_settings_new,
                                          size: 48,
                                          color: const Color(0xFF35D0BA),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _connected
                                    ? (_fa
                                        ? 'برای قطع لمس کن'
                                        : 'Tap to disconnect')
                                    : (_fa
                                        ? 'برای اتصال لمس کن'
                                        : 'Tap to connect'),
                                style: const TextStyle(color: Colors.white60),
                              ),
                              if (_connection == _ConnectionUi.connecting &&
                                  _attemptCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    _fa
                                        ? 'تلاش $_currentAttempt از $_attemptCount'
                                        : 'Attempt $_currentAttempt of $_attemptCount',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (_connected && _activeServer != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    _activeServer!.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _busy || _connected ? null : _chooseServer,
                        icon: const Icon(Icons.public),
                        label: Text(
                          _preferredServer == null
                              ? (_fa
                                  ? 'انتخاب کشور و سرور'
                                  : 'Choose country and server')
                              : '${_fa ? 'انتخاب‌شده' : 'Selected'}: ${_preferredServer!.name}',
                        ),
                      ),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
