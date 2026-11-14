import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vpn_server.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _baseUrl = String.fromEnvironment('API_BASE_URL');

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured for this build.');
    }
    final base = Uri.parse(_baseUrl);
    if (base.scheme != 'https' && !(base.scheme == 'http' && (base.host == '10.0.2.2' || base.host == '127.0.0.1' || base.host == 'localhost'))) {
      throw StateError('The API must use HTTPS except for local development.');
    }
    return base.resolve(path);
  }

  Future<List<VpnServer>> fetchServers() async {
    final response = await _client.get(_uri('/api/v1/servers')).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw ApiException('Server list unavailable (${response.statusCode}).');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['servers'] is! List) {
      throw const FormatException('Invalid server-list response.');
    }
    return (decoded['servers'] as List)
        .map((item) => VpnServer.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
