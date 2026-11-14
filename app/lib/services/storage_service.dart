import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _serverKey = 'nova.selected_server';
  static const _languageKey = 'nova.language';

  Future<String?> readServerId() async =>
      (await SharedPreferences.getInstance()).getString(_serverKey);

  Future<void> writeServerId(String id) async =>
      (await SharedPreferences.getInstance()).setString(_serverKey, id);

  Future<String> readLanguage() async =>
      (await SharedPreferences.getInstance()).getString(_languageKey) ?? 'fa';

  Future<void> writeLanguage(String language) async =>
      (await SharedPreferences.getInstance()).setString(_languageKey, language);
}
