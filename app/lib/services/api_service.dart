import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vpn_server.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const _baseUrl = String.fromEnvironment('API_BASE_URL');

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) throw StateError('API_BASE_URL is not configured for this build.');
    final base = Uri.parse(_baseUrl);
    const localHosts = {'10.0.2.2', '127.0.0.1', 'localhost'};
    if (base.scheme != 'https' && !(base.scheme == 'http' && localHosts.contains(base.host))) {
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

  /// Fetches a profile only at connect time. The server currently disables this
  /// endpoint until end-user authorization and abuse controls are deployed.
  Future<String> fetchServerConfig(String serverId) async {
    final path = '/api/v1/servers/${Uri.encodeComponent(serverId)}/config';
    final response = await _client.get(_uri(path), headers: const {'Cache-Control': 'no-store'}).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw ApiException('Server profile unavailable (${response.statusCode}).');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['config'] is! String || (decoded['config'] as String).isEmpty) {
      throw const FormatException('Invalid profile response.');
    }
    return decoded['config'] as String;
  }

  void close() => _client.close();
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
