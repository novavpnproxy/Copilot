import 'dart:async';
import 'package:flutter/material.dart';
import '../models/vpn_server.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();
  late Future<List<VpnServer>> _servers;
  VpnServer? _selected;
  String _language = 'fa';

  bool get _fa => _language == 'fa';

  @override
  void initState() {
    super.initState();
    _servers = _loadServers();
    _storage.readLanguage().then((value) {
      if (mounted) setState(() => _language = value);
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
    if (_selected != null && !servers.any((s) => s.id == _selected!.id)) {
      _selected = null;
    }
    return servers;
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  String _countryName(VpnServer server) {
    if (!server.locationVerified) return _fa ? 'موقعیت نامشخص' : 'Unknown location';
    return _fa
        ? (server.countryNameFa ?? server.countryCode ?? 'موقعیت نامشخص')
        : (server.countryNameEn ?? server.countryCode ?? 'Unknown location');
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _fa ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: const Text('NOVA VPN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            actions: [
              IconButton(
                tooltip: _fa ? 'تنظیمات' : 'Settings',
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  final language = await _storage.readLanguage();
                  if (mounted) setState(() => _language = language);
                },
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(tooltip: _fa ? 'تازه‌سازی سرورها' : 'Refresh servers', onPressed: _refresh, icon: const Icon(Icons.refresh)),
            ],
          ),
          body: SafeArea(
            child: FutureBuilder<List<VpnServer>>(
              future: _servers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) {
                  return _message(
                    _fa ? 'دریافت فهرست سرورها ناموفق بود.' : 'Could not load servers.',
                    action: TextButton(onPressed: _refresh, child: Text(_fa ? 'تلاش دوباره' : 'Try again')),
                  );
                }
                final servers = snapshot.data ?? const <VpnServer>[];
                if (servers.isEmpty) {
                  return _emptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    _brandCard(context),
                    const SizedBox(height: 22),
                    _sectionHeading(_fa ? 'مکان اتصال' : 'Connection location', _fa ? '${servers.length} سرور فعال' : '${servers.length} active servers'),
                    const SizedBox(height: 12),
                    ...servers.map(_serverTile),
                    const SizedBox(height: 16),
                    _engineNotice(),
                  ]),
                );
              },
            ),
          ),
        ),
      );

  Widget _brandCard(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF173650), Color(0xFF101A2B), Color(0xFF0D1928)]),
          border: Border.all(color: const Color(0xFF35D0BA).withValues(alpha: .28)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Column(children: [
          const Icon(Icons.shield_moon_outlined, size: 62, color: Color(0xFF35D0BA)),
          const SizedBox(height: 10),
          const Text('NOVA VPN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21, letterSpacing: 2)),
          const SizedBox(height: 5),
          const Text('JEYRAN GROUP', style: TextStyle(color: Colors.white60, letterSpacing: 2, fontSize: 12)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .045), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.info_outline, size: 17, color: Color(0xFF35D0BA)),
              const SizedBox(width: 8),
              Flexible(child: Text(_fa ? 'موتور اتصال هنوز آماده نشده' : 'VPN engine is not configured', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13))),
            ]),
          ),
        ]),
      );

  Widget _sectionHeading(String title, String subtitle) => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12))])),
        const Icon(Icons.public, color: Color(0xFF35D0BA)),
      ]);

  Widget _serverTile(VpnServer server) {
    final selected = _selected?.id == server.id;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      color: const Color(0xFF101A2B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: selected ? const Color(0xFF35D0BA).withValues(alpha: .75) : Colors.white.withValues(alpha: .06))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        leading: CircleAvatar(backgroundColor: const Color(0xFF35D0BA).withValues(alpha: .12), child: Icon(Icons.public, color: selected ? const Color(0xFF35D0BA) : Colors.white70)),
        title: Text(server.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${_countryName(server)} · ${server.protocol}', style: const TextStyle(color: Colors.white60)),
        trailing: Icon(selected ? Icons.check_circle : Icons.radio_button_off, color: selected ? const Color(0xFF35D0BA) : Colors.white30),
        onTap: () async {
          setState(() => _selected = server);
          await _storage.writeServerId(server.id);
        },
      ),
    );
  }

  Widget _engineNotice() => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF2A2519), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFC857).withValues(alpha: .25))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC857)),
          const SizedBox(width: 10),
          Expanded(child: Text(_fa ? 'اتصال VPN در این نسخه غیرفعال است تا موتور واقعی اندروید و تأیید وضعیت آن پیاده‌سازی شود. هیچ وضعیت اتصال ساختگی نمایش داده نمی‌شود.' : 'VPN connection is disabled until a real Android engine and its verified status callbacks are integrated. No fake connection state is shown.', style: const TextStyle(color: Colors.white70, height: 1.45, fontSize: 12))),
        ]),
      );

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 54, color: Colors.white38),
            const SizedBox(height: 14),
            Text(_fa ? 'سرور فعالی ثبت نشده است' : 'No active servers are configured', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_fa ? 'مدیر باید سرور واقعی را از پنل جداگانه اضافه و فعال کند.' : 'The owner must add and enable a real server in the separate admin panel.', style: const TextStyle(color: Colors.white60), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: Text(_fa ? 'تازه‌سازی' : 'Refresh')),
          ]),
        ),
      );

  Widget _message(String text, {Widget? action}) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(text, textAlign: TextAlign.center), if (action != null) action])));

  void _refresh() {
    setState(() {
      _selected = null;
      _servers = _loadServers();
    });
  }
}
