import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  String _language = 'fa';

  @override
  void initState() {
    super.initState();
    _storage.readLanguage().then((value) {
      if (mounted) setState(() => _language = value);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_language == 'fa' ? 'تنظیمات' : 'Settings')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
            title: Text(_language == 'fa' ? 'زبان' : 'Language'),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [
                DropdownMenuItem(value: 'fa', child: Text('فارسی')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                await _storage.writeLanguage(value);
                if (mounted) setState(() => _language = value);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(_language == 'fa' ? 'دربارهٔ NOVA VPN' : 'About NOVA VPN'),
            subtitle: const Text('JEYRAN GROUP · 0.1.0'),
          ),
          ListTile(
            title: Text(_language == 'fa' ? 'حریم خصوصی' : 'Privacy'),
            subtitle: Text(_language == 'fa'
                ? 'سیاست حریم خصوصی تا پیش از انتشار عمومی باید تکمیل شود.'
                : 'The privacy policy must be completed before public release.'),
          ),
        ]),
      );
}
