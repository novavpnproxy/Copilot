import 'dart:math';
import 'package:crypto/crypto.dart';

import '../Storage/secure_storage_service.dart';

class DeviceService {
  DeviceService({SecureStorageService? storage})
      : _storage = storage ?? const SecureStorageService();

  final SecureStorageService _storage;
  final Random _random = Random.secure();

  Future<String> getOrCreateDeviceId() async {
    final saved = await _storage.readDeviceId();
    if (saved != null && saved.length == 64) return saved;

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final id = sha256.convert(bytes).toString();

    await _storage.writeDeviceId(id);
    return id;
  }

  Future<void> clear() async {
    await _storage.clearDeviceId();
  }
}
