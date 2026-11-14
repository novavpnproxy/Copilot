import 'dart:async';
import 'dart:convert';

import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Android VPN engine adapter. The engine is a singleton so its native event
/// listener remains active while screens are rebuilt or navigated.
class VpnService {
  VpnService._() : _engine = V2ray(onStatusChanged: _publishStatus);

  static final VpnService instance = VpnService._();
  factory VpnService() => instance;

  static final StreamController<V2RayStatus> _statuses =
      StreamController<V2RayStatus>.broadcast();
  static bool _initialized = false;
  static Future<void>? _initializing;
  static V2RayStatus _latestStatus = V2RayStatus();

  final V2ray _engine;

  static void _publishStatus(V2RayStatus status) {
    _latestStatus = status;
    if (!_statuses.isClosed) _statuses.add(status);
  }

  Stream<V2RayStatus> get statusChanges => _statuses.stream;
  V2RayStatus get currentStatus => _latestStatus;

  Future<void> initialize() async {
    if (_initialized) return;
    final pending = _initializing;
    if (pending != null) return pending;
    final future = _engine.initialize(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    _initializing = future;
    try {
      await future;
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  /// Starts a profile and waits for an explicit native CONNECTED event.
  /// Method-channel completion alone is not treated as an established tunnel.
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
      await _stopPreservingFailure();
      throw const VpnConnectionTimeoutException();
    } on VpnPermissionException {
      rethrow;
    } catch (_) {
      await _stopPreservingFailure();
      // Do not surface plugin/native text: it can contain profile details.
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

  Future<void> _stopPreservingFailure() async {
    try {
      await _engine.stopV2Ray();
    } catch (_) {
      // Keep the original error for the bounded failover controller.
    }
  }

  Future<void> disconnect() => _engine.stopV2Ray();
}

class VpnPermissionException implements Exception {
  const VpnPermissionException();
}

class VpnConnectionException implements Exception {
  const VpnConnectionException();
}

class VpnConnectionTimeoutException implements Exception {
  const VpnConnectionTimeoutException();
}
