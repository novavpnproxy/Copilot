import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vpn_server.dart';
import '../storage/secure_storage_service.dart';

class ApiService {
  ApiService({
    http.Client? client,
    SecureStorageService? storage,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const SecureStorageService(),
        _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final SecureStorageService _storage;
  final String _baseUrl;

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured.');
    }

    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasAuthority) {
      throw StateError('API_BASE_URL is invalid.');
    }

    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    final localHttp = base.scheme == 'http' && localHosts.contains(base.host);

    if (base.scheme != 'https' && !localHttp) {
      throw StateError('The API must use HTTPS except for local development.');
    }

    return base.resolve(path);
  }

  Future<List<VpnServer>> fetchServers() async {
    final response = await _client
        .get(
          _uri('/api/v1/servers'),
          headers: const {'Cache-Control': 'no-store'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw ApiException('Server list unavailable.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['servers'] is! List) {
      throw const FormatException('Invalid server-list response.');
    }

    return (decoded['servers'] as List)
        .map((item) =>
            VpnServer.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<String> fetchServerConfig(String serverId) async {
    final token = await _storage.readAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw const ApiException('Device authentication is required.');
    }

    final path =
        '/api/v1/servers/${Uri.encodeComponent(serverId)}/config';

    final response = await _client
        .get(
          _uri(path),
          headers: {
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-store',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _storage.clearAccessToken();
      throw const ApiException('Device authentication expired.');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Server profile unavailable (${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['config'] is! String ||
        (decoded['config'] as String).trim().isEmpty) {
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
