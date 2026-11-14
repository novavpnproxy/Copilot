import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

import '../models/vpn_server.dart';
import '../services/api_service.dart';
import '../services/connection_failover.dart';
import '../services/storage_service.dart';
import '../services/vpn_service.dart';
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
  late Future<List<VpnServer>> _servers;
  _ConnectionUi _connection = _ConnectionUi.disconnected;
  VpnServer? _connectedServer;
  String _language = 'fa';
  String? _message;
  String _duration = '00:00:00';
  bool _busy = false;
  bool _failoverRunning = false;
  int _currentAttempt = 0;
  int _attemptCount = 0;

  bool get _fa => _language == 'fa';
  bool get _connected => _connection == _ConnectionUi.connected;

  @override
  void initState() {
    super.initState();
    _servers = _api.fetchServers();
    _storage.readLanguage().then((value) {
      if (mounted) setState(() => _language = value);
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
          }
          break;
        case 'ERROR':
          if (!_failoverRunning) {
            _connection = _ConnectionUi.error;
            _message = _fa ? 'موتور VPN اتصال را برقرار نکرد.' : 'VPN engine failed to connect.';
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

  Future<void> _toggleConnection() async {
    if (_busy) return;
    if (_connected) {
      setState(() {
        _busy = true;
        _connection = _ConnectionUi.disconnecting;
        _message = null;
      });
      try {
        await _vpn.disconnect();
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
      return;
    }

    setState(() {
      _busy = true;
      _failoverRunning = true;
      _connection = _ConnectionUi.connecting;
      _message = null;
      _currentAttempt = 0;
    });

    try {
      final servers = await _servers;
      if (!mounted) return;
      if (servers.isEmpty) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa ? 'سرور فعالی در پنل مدیر ثبت نشده است.' : 'No active servers are configured.';
        });
        return;
      }

      final savedId = await _storage.readServerId();
      final candidates = <VpnServer>[
        ...servers.where((server) => server.id == savedId),
        ...servers.where((server) => server.id != savedId),
      ];
      _attemptCount = candidates.length;
      final connectedServer = await connectWithFallback<VpnServer>(
        candidates: candidates,
        isFatal: (error) => error is ApiException || error is VpnPermissionException,
        onAttempt: (server, index) {
          if (!mounted) return;
          setState(() {
            _currentAttempt = index + 1;
            _connectedServer = server;
            _connection = _ConnectionUi.connecting;
            _message = index == 0
                ? (_fa ? 'در حال اتصال…' : 'Connecting…')
                : (_fa ? 'سرور قبلی ناموفق بود؛ تلاش با سرور بعدی…' : 'Previous server failed; trying next server…');
          });
        },
        attempt: (server) async {
          // Profile is requested just in time and is never persisted or rendered.
          final profile = await _api.fetchServerConfig(server.id);
          await _vpn.connect(profile: profile, remark: server.name);
        },
      );
      if (!mounted) return;
      await _storage.writeServerId(connectedServer.id);
      setState(() {
        _connectedServer = connectedServer;
        _connection = _ConnectionUi.connected;
        _message = null;
      });
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
              ? 'دریافت پروفایل از سرویس ممکن نیست؛ دسترسی امن کاربران هنوز فعال نشده است.'
              : 'Secure profile access is not enabled on the backend yet.';
        });
      }
    } on AllCandidatesFailedException catch (error) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa
              ? 'اتصال به هیچ‌یک از ${error.attemptedCount} سرور برقرار نشد.'
              : 'Could not connect to any of the ${error.attemptedCount} servers.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connection = _ConnectionUi.error;
          _message = _fa ? 'اتصال VPN برقرار نشد.' : 'VPN connection failed.';
        });
      }
    } finally {
      _failoverRunning = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshServers() async {
    setState(() {
      _servers = _api.fetchServers();
      _message = _fa ? 'فهرست سرورها تازه شد.' : 'Server list refreshed.';
    });
    try {
      await _servers;
    } catch (_) {
      if (mounted) setState(() => _message = _fa ? 'دریافت فهرست سرورها ناموفق بود.' : 'Could not load servers.');
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
            title: const Text('NOVA VPN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            actions: [
              IconButton(
                tooltip: _fa ? 'تازه‌سازی' : 'Refresh',
                onPressed: _busy ? null : _refreshServers,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: _fa ? 'تنظیمات' : 'Settings',
                onPressed: _busy
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        final language = await _storage.readLanguage();
                        if (mounted) setState(() => _language = language);
                      },
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_moon_outlined, size: 78, color: Color(0xFF35D0BA)),
                      const SizedBox(height: 12),
                      const Text('NOVA VPN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      const Text('JEYRAN GROUP', style: TextStyle(color: Colors.white54, letterSpacing: 2)),
                      const SizedBox(height: 32),
                      Card(
                        color: const Color(0xFF101A2B),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(_stateLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _connected ? const Color(0xFF35D0BA) : Colors.white70)),
                              if (_connected) Padding(padding: const EdgeInsets.only(top: 7), child: Text(_duration, style: const TextStyle(color: Colors.white60))),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: 132,
                                height: 132,
                                child: OutlinedButton(
                                  onPressed: _busy ? null : _toggleConnection,
                                  style: OutlinedButton.styleFrom(
                                    shape: const CircleBorder(),
                                    side: const BorderSide(color: Color(0xFF35D0BA), width: 2),
                                    backgroundColor: const Color(0xFF35D0BA).withValues(alpha: .07),
                                  ),
                                  child: _busy
                                      ? const CircularProgressIndicator()
                                      : Icon(_connected ? Icons.stop_rounded : Icons.power_settings_new, size: 48, color: const Color(0xFF35D0BA)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(_connected ? (_fa ? 'برای قطع لمس کن' : 'Tap to disconnect') : (_fa ? 'برای اتصال لمس کن' : 'Tap to connect'), style: const TextStyle(color: Colors.white60)),
                              if (_connection == _ConnectionUi.connecting && _attemptCount > 0)
                                Padding(padding: const EdgeInsets.only(top: 10), child: Text(_fa ? 'تلاش $_currentAttempt از $_attemptCount' : 'Attempt $_currentAttempt of $_attemptCount', style: const TextStyle(color: Colors.white54, fontSize: 12))),
                              if (_connectedServer != null)
                                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_connectedServer!.name, style: const TextStyle(color: Colors.white70))),
                            ],
                          ),
                        ),
                      ),
                      if (_message != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.45))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
