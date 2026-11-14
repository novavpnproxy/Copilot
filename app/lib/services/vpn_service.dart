import 'dart:async';
import 'dart:convert';

import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Android Xray/V2Ray adapter. A tunnel attempt succeeds only after the native
/// engine emits CONNECTED; completion of startV2Ray alone is not success.
class VpnService {
  VpnService._() : _engine = V2ray(onStatusChanged: _handleNativeStatus);

  static final VpnService instance = VpnService._();
  factory VpnService() => instance;

  static final StreamController<V2RayStatus> _statuses =
      StreamController<V2RayStatus>.broadcast();
  static bool _initialized = false;
  static V2RayStatus _latestStatus = V2RayStatus();

  final V2ray _engine;

  static void _handleNativeStatus(V2RayStatus status) {
    _latestStatus = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }

  Stream<V2RayStatus> get statusChanges => _statuses.stream;
  V2RayStatus get currentStatus => _latestStatus;

  Future<void> initialize() async {
    if (_initialized) return;
    await _engine.initialize(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    _initialized = true;
  }

  /// Starts one profile and waits for an explicit engine state. A timeout or
  /// native failure is reported to the caller so it may try another server.
  Future<void> connect({
    required String profile,
    required String remark,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    await initialize();
    if (!await _engine.requestPermission()) {
      throw const VpnPermissionException();
    }

    final config = _toEngineConfig(profile);
    final result = Completer<void>();
    var sawConnecting = false;
    final subscription = statusChanges.listen((status) {
      final state = status.state.toUpperCase();
      if (state == 'CONNECTING') sawConnecting = true;
      if (state == 'CONNECTED' && !result.isCompleted) result.complete();
      if ((state == 'ERROR' || (state == 'DISCONNECTED' && sawConnecting)) &&
          !result.isCompleted) {
        result.completeError(const VpnConnectionException());
      }
    });

    try {
      await _engine.startV2Ray(
        remark: remark,
        config: config,
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
        notificationDisconnectButtonName: 'DISCONNECT',
      );
      await result.future.timeout(timeout);
    } on TimeoutException {
      try {
        await _engine.stopV2Ray();
      } catch (_) {
        // Preserve the timeout so failover can move to another server.
      }
      throw const VpnConnectionTimeoutException();
    } catch (_) {
      // Do not leak plugin exception details, which may contain profile material.
      try {
        await _engine.stopV2Ray();
      } catch (_) {
        // Preserve the original connection failure.
      }
      throw const VpnConnectionException();
    } finally {
      await subscription.cancel();
    }
  }

  String _toEngineConfig(String profile) {
    final trimmed = profile.trim();
    if (trimmed.isEmpty) throw const FormatException('Empty VPN profile.');
    if (trimmed.contains('://')) {
      return V2ray.parseFromURL(trimmed).getFullConfiguration();
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Profile must be a JSON object or supported share link.');
    }
    return trimmed;
  }

  Future<void> disconnect() => _engine.stopV2Ray();
}

class VpnPermissionException implements Exception {
  const VpnPermissionException();
  @override
  String toString() => 'VPN permission was not granted.';
}

class VpnConnectionException implements Exception {
  const VpnConnectionException();
  @override
  String toString() => 'VPN engine did not establish the tunnel.';
}

class VpnConnectionTimeoutException implements Exception {
  const VpnConnectionTimeoutException();
  @override
  String toString() => 'VPN connection timed out.';
}
