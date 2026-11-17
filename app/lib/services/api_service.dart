import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vpn_server.dart';

/// دریافت متادیتای عمومی سرورها و پروفایل هنگام اتصال.
/// پروفایل خام در این سرویس ذخیره یا در پاسخ فهرست سرورها قرار نمی‌گیرد.
class ApiService {
  ApiService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL');

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path) {
    if (_baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not configured for this build.');
    }

    final base = Uri.tryParse(_baseUrl);
    if (base == null || !base.hasAuthority || base.host.isEmpty) {
      throw StateError('API_BASE_URL is invalid.');
    }

    const localHosts = {'10.0.2.2', '127.0.0.1', 'localhost'};
    final localHttp = base.scheme == 'http' && localHosts.contains(base.host);

    if (base.scheme != 'https' && !localHttp) {
      throw StateError('The API must use HTTPS except for local development.');
    }
    if (base.userInfo.isNotEmpty || base.hasQuery || base.hasFragment) {
      throw StateError(
        'API_BASE_URL must not contain credentials, query, or fragment.',
      );
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
      throw ApiException('Server list unavailable (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['servers'] is! List) {
      throw const FormatException('Invalid server-list response.');
    }

    return (decoded['servers'] as List)
        .map(
          (item) => VpnServer.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  /// کانفیگ فقط هنگام اتصال درخواست می‌شود.
  /// بک‌اند فعلاً عمداً این مسیر را تا آماده‌شدن احراز هویت کاربر می‌بندد.
  Future<String> fetchServerConfig(String serverId) async {
    if (serverId.isEmpty) {
      throw const FormatException('Server ID is empty.');
    }

    final path = '/api/v1/servers/${Uri.encodeComponent(serverId)}/config';
    final response = await _client
        .get(
          _uri(path),
          headers: const {'Cache-Control': 'no-store'},
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      // بدنهٔ پاسخ سرور را به UI منتقل نمی‌کنیم.
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
