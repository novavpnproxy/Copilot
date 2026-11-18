import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for short-lived tokens and an install-random device identifier.
/// Raw VPN profiles must not be stored here.
class SecureStorageService {
  const SecureStorageService();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _accessTokenKey = 'nova_access_token';
  static const _deviceIdKey = 'nova_device_id';

  Future<void> writeAccessToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Token cannot be empty.');
    }
    await _storage.write(key: _accessTokenKey, value: value);
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<void> clearAccessToken() => _storage.delete(key: _accessTokenKey);

  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);

  Future<void> writeDeviceId(String deviceId) async {
    final value = deviceId.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Device ID cannot be empty.');
    }
    await _storage.write(key: _deviceIdKey, value: value);
  }

  Future<void> clearDeviceId() => _storage.delete(key: _deviceIdKey);
}
