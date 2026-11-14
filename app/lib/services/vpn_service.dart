import 'dart:async';
import 'dart:convert';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Android Xray/V2Ray adapter. Connection state comes from the plugin event
/// callback; startV2Ray completing is not treated as a successful connection.
class VpnService {
  VpnService() : _engine = V2ray(onStatusChanged: _onStatus);

  static final StreamController<String> _states = StreamController<String>.broadcast();
  static bool _initialized = false;
  static V2ray? _sharedEngine;
  final V2ray _engine;

  static void _onStatus(V2RayStatus status) {
    _states.add(status.state.toUpperCase());
  }

  Stream<String> get statusChanges => _states.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    await _engine.initialize(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    _sharedEngine = _engine;
    _initialized = true;
  }

  Future<void> connect({required String profile, required String remark}) async {
    await initialize();
    if (!await _engine.requestPermission()) {
      throw const VpnPermissionException();
    }

    final trimmed = profile.trim();
    final config = trimmed.contains('://')
        ? V2ray.parseFromURL(trimmed).getFullConfiguration()
        : _validateJsonConfig(trimmed);

    // Keep profile local to this operation and never log or expose it in the UI.
    await _engine.startV2Ray(
      remark: remark,
      config: config,
      blockedApps: null,
      bypassSubnets: null,
      proxyOnly: false,
      notificationDisconnectButtonName: 'DISCONNECT',
    );
  }

  String _validateJsonConfig(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('VPN profile must be a JSON object or supported share link.');
    }
    return value;
  }

  Future<void> disconnect() async {
    final engine = _sharedEngine ?? _engine;
    await engine.stopV2Ray();
  }
}

class VpnPermissionException implements Exception {
  const VpnPermissionException();
  @override
  String toString() => 'VPN permission was not granted.';
}
