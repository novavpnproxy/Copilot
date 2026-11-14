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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _servers = _loadServers();
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
    _timer?.cancel();
    _api.close();
    super.dispose();
  }

  String _countryName(VpnServer server) => server.locationVerified
      ? (server.countryNameFa ?? server.countryCode ?? 'موقعیت نامشخص')
      : 'موقعیت نامشخص';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('NOVA VPN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          actions: [
            IconButton(tooltip: 'تنظیمات', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
            IconButton(tooltip: 'تازه‌سازی سرورها', onPressed: _refresh, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<List<VpnServer>>(
            future: _servers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return _message('دریافت فهرست سرورها ناموفق بود.', action: TextButton(onPressed: _refresh, child: const Text('تلاش دوباره')));
              final servers = snapshot.data ?? const <VpnServer>[];
              if (servers.isEmpty) return _message('در حال حاضر سرور فعالی در دسترس نیست.');
              return ListView(padding: const EdgeInsets.all(16), children: [
                const _BrandCard(),
                const SizedBox(height: 22),
                const Text('انتخاب سرور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...servers.map((server) {
                  final selected = _selected?.id == server.id;
                  return Card(
                    color: const Color(0xFF101A2B),
                    child: ListTile(
                      selected: selected,
                      leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Theme.of(context).colorScheme.primary : null),
                      title: Text(server.name),
                      subtitle: Text('${_countryName(server)} · ${server.protocol}'),
                      onTap: () async {
                        setState(() => _selected = server);
                        await _storage.writeServerId(server.id);
                      },
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text('موتور اتصال VPN هنوز به این نسخه افزوده نشده است؛ اتصال یا وضعیت ساختگی نمایش داده نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.5)),
              ]);
            },
          ),
        ),
      );

  void _refresh() {
    setState(() {
      _selected = null;
      _servers = _loadServers();
    });
  }

  Widget _message(String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [Text(text, textAlign: TextAlign.center), if (action != null) action]),
        ),
      );
}

class _BrandCard extends StatelessWidget {
  const _BrandCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Color(0xFF172D43), Color(0xFF102238)]),
          border: Border.all(color: const Color(0xFF35D0BA).withValues(alpha: .25)),
        ),
        child: const Column(children: [
          Icon(Icons.shield_moon_outlined, size: 58, color: Color(0xFF35D0BA)),
          SizedBox(height: 10),
          Text('NOVA VPN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)),
          SizedBox(height: 6),
          Text('JEYRAN GROUP', style: TextStyle(color: Colors.white60, letterSpacing: 2)),
        ]),
      );
}
