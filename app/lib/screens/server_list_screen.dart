// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../models/vpn_server.dart';
import '../services/api_service.dart';

/// Lets users choose only from server metadata returned by the backend.
/// Raw VPN profiles are never fetched or displayed on this screen.
class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key, required this.language});

  final String language;

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  final ApiService _api = ApiService();
  late Future<List<VpnServer>> _servers;

  bool get _fa => widget.language == 'fa';

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

  String _countryName(VpnServer server) {
    if (!server.locationVerified) {
      return _fa ? 'موقعیت نامشخص' : 'Unknown location';
    }
    return (_fa ? server.countryNameFa : server.countryNameEn) ??
        (_fa ? 'موقعیت نامشخص' : 'Unknown location');
  }

  String _flag(VpnServer server) {
    final code = server.locationVerified ? server.countryCode : null;
    if (code == null || code.length != 2) return '🌐';
    return String.fromCharCodes(code.toUpperCase().codeUnits.map(
      (unit) => 0x1F1E6 + unit - 0x41,
    ));
  }

  Map<String, List<VpnServer>> _group(List<VpnServer> servers) {
    final groups = <String, List<VpnServer>>{};
    for (final server in servers) {
      final key = server.locationVerified && server.countryCode != null
          ? server.countryCode!
          : 'UNKNOWN';
      (groups[key] ??= []).add(server);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _fa ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_fa ? 'انتخاب کشور و سرور' : 'Choose country and server'),
          ),
          body: FutureBuilder<List<VpnServer>>(
            future: _servers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  message: _fa
                      ? 'دریافت فهرست سرورها ممکن نیست. اتصال اینترنت و نشانی API را بررسی کنید.'
                      : 'Could not load servers. Check the network and API address.',
                  actionLabel: _fa ? 'تلاش دوباره' : 'Retry',
                  onAction: () => setState(() => _servers = _api.fetchServers()),
                );
              }

              final servers = snapshot.data ?? const <VpnServer>[];
              if (servers.isEmpty) {
                return Center(
                  child: Text(
                    _fa
                        ? 'در حال حاضر سرور فعالی وجود ندارد.'
                        : 'No active servers are available.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final groups = _group(servers);
              final countries = groups.keys.toList()
                ..sort((a, b) {
                  if (a == 'UNKNOWN') return 1;
                  if (b == 'UNKNOWN') return -1;
                  final nameA = _countryName(groups[a]!.first);
                  final nameB = _countryName(groups[b]!.first);
                  return nameA.compareTo(nameB);
                });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _fa
                        ? 'فقط سرورهای فعال پنل مدیریت نمایش داده می‌شوند.'
                        : 'Only servers enabled in the owner panel are shown.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white60),
                  ),
                  const SizedBox(height: 12),
                  for (final country in countries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: const Color(0xFF101A2B),
                      child: ExpansionTile(
                        leading: Text(
                          _flag(groups[country]!.first),
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(_countryName(groups[country]!.first)),
                        subtitle: Text(_fa
                            ? '${groups[country]!.length} سرور'
                            : '${groups[country]!.length} servers'),
                        children: [
                          for (var index = 0;
                              index < groups[country]!.length;
                              index++)
                            ListTile(
                              leading: const Icon(Icons.dns_outlined,
                                  color: Color(0xFF35D0BA)),
                              title: Text(_fa
                                  ? 'سرور ${index + 1}'
                                  : 'Server ${index + 1}'),
                              subtitle: Text(groups[country]![index].protocol),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context)
                                  .pop(groups[country]![index]),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      );
}
