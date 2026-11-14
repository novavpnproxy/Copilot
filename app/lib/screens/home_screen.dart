import 'package:flutter/material.dart';
import '../models/vpn_server.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  late Future<List<VpnServer>> _servers;
  VpnServer? _selected;

  @override
  void initState() {
    super.initState();
    _servers = _api.fetchServers();
  }

  @override
  void dispose() {
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
          actions: [IconButton(tooltip: 'تازه‌سازی فهرست', onPressed: () => setState(() { _selected = null; _servers = _api.fetchServers(); }), icon: const Icon(Icons.refresh))],
        ),
        body: SafeArea(
          child: FutureBuilder<List<VpnServer>>(
            future: _servers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return _message('دریافت فهرست سرورها ناموفق بود.', action: TextButton(onPressed: () => setState(() => _servers = _api.fetchServers()), child: const Text('تلاش دوباره')));
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
                      onTap: () => setState(() => _selected = server),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text('اتصال VPN در این نسخه هنوز فعال نشده است؛ تا زمان اتصال موتور واقعی و دریافت وضعیت تأییدشده، وضعیت اتصال یا دکمهٔ اتصال نمایش داده نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, height: 1.5)),
              ]);
            },
          ),
        ),
      );

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
