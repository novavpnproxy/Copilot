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
  late Future<List<VpnServer>> _servers;
  StreamSubscription<V2RayStatus>? _statusSubscription;
  VpnServer? _selected;
  String _language = 'fa';
  String? _errorMessage;
  String _duration = '00:00:00';
  _ConnectionUi _connection = _ConnectionUi.disconnected;
  bool _busy = false;
  bool _failoverRunning = false;

  bool get _fa => _language == 'fa';
  bool get _vpnConnected => _connection == _ConnectionUi.connected;

  @override
  void initState() {
    super.initState();
    _servers = _loadServers();
    _storage.readLanguage().then((value) {
      if (mounted) setState(() => _language = value);
    });
    _statusSubscription = _vpn.statusChanges.listen(_handleEngineStatus);
    _handleEngineStatus(_vpn.currentStatus);
  }

  void _handleEngineStatus(V2RayStatus status) {
    if (!mounted) return;
    setState(() {
      switch (status.state.toUpperCase()) {
        case 'CONNECTED':
          _connection = _ConnectionUi.connected;
          _errorMessage = null;
          _duration = status.duration;
          break;
        case 'DISCONNECTED':
          if (!_failoverRunning || _connection == _ConnectionUi.disconnecting) {
            _connection = _ConnectionUi.disconnected;
            _busy = false;
            _duration = '00:00:00';
          }
          break;
        case 'CONNECTING':
          _connection = _ConnectionUi.connecting;
          break;
        case 'DISCONNECTING':
          _connection = _ConnectionUi.disconnecting;
          break;
        case 'ERROR':
          _connection = _ConnectionUi.error;
          if (!_failoverRunning) _busy = false;
          _errorMessage = _fa ? 'موتور VPN اتصال را برقرار نکرد.' : 'VPN engine failed to connect.';
          break;
        default:
          break;
      }
    });
  }

  Future<List<VpnServer>> _loadServers() async {
    final servers = await _api.fetchServers();
    final savedId = await _storage.readServerId();
    if (savedId != null) {
      for (final server in servers) {
        if (server.id == savedId) _selected = server;
      }
    }
    if (_selected != null && !servers.any((s) => s.id == _selected!.id)) _selected = null;
    return servers;
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _api.close();
    super.dispose();
  }

  String _countryName(VpnServer server) {
    if (!server.locationVerified) return _fa ? 'موقعیت نامشخص' : 'Unknown location';
    return _fa ? (server.countryNameFa ?? server.countryCode ?? 'موقعیت نامشخص') : (server.countryNameEn ?? server.countryCode ?? 'Unknown location');
  }

  Future<void> _toggleConnection() async {
    if (_busy) return;
    if (_vpnConnected) {
      setState(() { _busy = true; _connection = _ConnectionUi.disconnecting; _errorMessage = null; });
      try {
        await _vpn.disconnect();
      } catch (error) {
        if (mounted) setState(() { _busy = false; _connection = _ConnectionUi.error; _errorMessage = _safeError(error); });
      }
      return;
    }

    final selected = _selected;
    if (selected == null) {
      _showMessage(_fa ? 'ابتدا یک سرور انتخاب کن.' : 'Select a server first.');
      return;
    }
    final servers = await _servers;
    if (!mounted) return;
    final candidates = <VpnServer>[selected, ...servers.where((server) => server.id != selected.id)];
    setState(() { _busy = true; _failoverRunning = true; _connection = _ConnectionUi.connecting; _errorMessage = null; });

    try {
      final connectedServer = await connectWithFallback<VpnServer>(
        candidates: candidates,
        isFatal: (error) => error is VpnPermissionException || error is ApiException,
        onAttempt: (server, index) {
          if (!mounted) return;
          setState(() {
            _selected = server;
            _connection = _ConnectionUi.connecting;
            _errorMessage = index == 0 ? null : (_fa ? 'سرور قبلی ناموفق بود؛ تلاش با ${server.name}…' : 'Previous server failed; trying ${server.name}…');
          });
        },
        attempt: (server) async {
          final profile = await _api.fetchServerConfig(server.id);
          await _vpn.connect(profile: profile, remark: server.name);
        },
      );
      if (!mounted) return;
      await _storage.writeServerId(connectedServer.id);
      setState(() { _connection = _ConnectionUi.connected; _errorMessage = null; });
    } on VpnPermissionException catch (error) {
      if (mounted) setState(() { _connection = _ConnectionUi.disconnected; _errorMessage = _safeError(error); });
    } on ApiException catch (error) {
      if (mounted) setState(() { _connection = _ConnectionUi.error; _errorMessage = _safeError(error); });
    } on AllCandidatesFailedException catch (error) {
      if (mounted) setState(() {
        _connection = _ConnectionUi.error;
        _errorMessage = _fa
            ? 'اتصال به هیچ‌یک از ${error.attemptedCount} سرور برقرار نشد.'
            : 'Could not connect to any of the ${error.attemptedCount} servers.';
      });
    } catch (error) {
      if (mounted) setState(() { _connection = _ConnectionUi.error; _errorMessage = _safeError(error); });
    } finally {
      _failoverRunning = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  String _safeError(Object error) {
    if (error is VpnPermissionException) return _fa ? 'مجوز VPN داده نشد.' : 'VPN permission was denied.';
    if (error is ApiException) return _fa ? 'دریافت امن پروفایل ممکن نیست؛ دسترسی کاربران هنوز در Backend فعال نشده است.' : 'Secure profile access is not enabled on the backend yet.';
    if (error is FormatException || error is ArgumentError) return _fa ? 'ساختار پروفایل سرور معتبر نیست.' : 'Server profile format is invalid.';
    if (error is VpnConnectionTimeoutException) return _fa ? 'مهلت اتصال سرور تمام شد.' : 'Server connection timed out.';
    return _fa ? 'اتصال VPN برقرار نشد.' : 'VPN connection failed.';
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

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
              IconButton(tooltip: _fa ? 'تنظیمات' : 'Settings', onPressed: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())); final language = await _storage.readLanguage(); if (mounted) setState(() => _language = language); }, icon: const Icon(Icons.settings_outlined)),
              IconButton(tooltip: _fa ? 'تازه‌سازی سرورها' : 'Refresh servers', onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          body: SafeArea(
            child: FutureBuilder<List<VpnServer>>(
              future: _servers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return _message(_fa ? 'دریافت فهرست سرورها ناموفق بود.' : 'Could not load servers.', action: TextButton(onPressed: _refresh, child: Text(_fa ? 'تلاش دوباره' : 'Try again')));
                final servers = snapshot.data ?? const <VpnServer>[];
                if (servers.isEmpty) return _emptyState();
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    _brandCard(),
                    const SizedBox(height: 17),
                    _connectionCard(),
                    if (_errorMessage != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A80)))),
                    const SizedBox(height: 22),
                    _sectionHeading(_fa ? 'مکان اتصال' : 'Connection location', _fa ? '${servers.length} سرور فعال' : '${servers.length} active servers'),
                    const SizedBox(height: 12),
                    ...servers.map(_serverTile),
                  ]),
                );
              },
            ),
          ),
        ),
      );

  Widget _brandCard() => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF173650), Color(0xFF101A2B), Color(0xFF0D1928)]), border: Border.all(color: const Color(0xFF35D0BA).withValues(alpha: .25))),
        child: const Column(children: [Icon(Icons.shield_moon_outlined, size: 50, color: Color(0xFF35D0BA)), SizedBox(height: 7), Text('NOVA VPN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)), SizedBox(height: 4), Text('JEYRAN GROUP', style: TextStyle(color: Colors.white60, letterSpacing: 2, fontSize: 11))]),
      );

  Widget _connectionCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: const Color(0xFF101A2B), borderRadius: BorderRadius.circular(20), border: Border.all(color: _vpnConnected ? const Color(0xFF35D0BA) : Colors.white12)),
        child: Column(children: [
          Text(_stateLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _vpnConnected ? const Color(0xFF35D0BA) : Colors.white70)),
          if (_vpnConnected) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_duration, style: const TextStyle(color: Colors.white60))),
          const SizedBox(height: 13),
          SizedBox(width: 112, height: 112, child: OutlinedButton(
            onPressed: _busy ? null : _toggleConnection,
            style: OutlinedButton.styleFrom(shape: const CircleBorder(), side: const BorderSide(color: Color(0xFF35D0BA), width: 2), backgroundColor: const Color(0xFF35D0BA).withValues(alpha: .07)),
            child: _busy ? const CircularProgressIndicator() : Icon(_vpnConnected ? Icons.stop_rounded : Icons.power_settings_new, size: 42, color: const Color(0xFF35D0BA)),
          )),
          const SizedBox(height: 9),
          Text(_vpnConnected ? (_fa ? 'برای قطع لمس کن' : 'Tap to disconnect') : (_fa ? 'برای اتصال لمس کن' : 'Tap to connect'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (_selected != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_selected!.name} · ${_countryName(_selected!)}', style: const TextStyle(color: Colors.white70))),
        ]),
      );

  Widget _sectionHeading(String title, String subtitle) => Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12))])), const Icon(Icons.public, color: Color(0xFF35D0BA))]);

  Widget _serverTile(VpnServer server) {
    final selected = _selected?.id == server.id;
    return Card(margin: const EdgeInsets.only(bottom: 9), color: const Color(0xFF101A2B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: selected ? const Color(0xFF35D0BA).withValues(alpha: .75) : Colors.white.withValues(alpha: .06))), child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      leading: CircleAvatar(backgroundColor: const Color(0xFF35D0BA).withValues(alpha: .12), child: Icon(Icons.public, color: selected ? const Color(0xFF35D0BA) : Colors.white70)),
      title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${_countryName(server)} · ${server.protocol}', style: const TextStyle(color: Colors.white60)),
      trailing: Icon(selected ? Icons.check_circle : Icons.radio_button_off, color: selected ? const Color(0xFF35D0BA) : Colors.white30),
      onTap: _vpnConnected || _busy ? null : () async { setState(() { _selected = server; _errorMessage = null; }); await _storage.writeServerId(server.id); },
    ));
  }

  Widget _emptyState() => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 54, color: Colors.white38), const SizedBox(height: 14), Text(_fa ? 'سرور فعالی ثبت نشده است' : 'No active servers are configured', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), textAlign: TextAlign.center), const SizedBox(height: 8), Text(_fa ? 'مدیر باید سرور واقعی را از پنل جداگانه اضافه و فعال کند.' : 'The owner must add and enable a real server in the separate admin panel.', style: const TextStyle(color: Colors.white60), textAlign: TextAlign.center), const SizedBox(height: 12), TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: Text(_fa ? 'تازه‌سازی' : 'Refresh'))])));

  Widget _message(String text, {Widget? action}) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(text, textAlign: TextAlign.center), if (action != null) action])));

  void _refresh() {
    setState(() { _selected = null; _servers = _loadServers(); });
  }
}
