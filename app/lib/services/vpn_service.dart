import 'dart:async';
import 'dart:convert';

import 'package:flutter_v2ray_client/flutter_v2ray.dart';

/// Singleton adapter around the Android Xray/V2Ray engine.
///
/// Profile text is accepted only for the duration of a connection attempt; this
/// service never stores or logs it. `connect` completes only after an explicit
/// native `CONNECTED` event, not just after the method-channel start call.
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
  bool _attemptInProgress = false;

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

  Future<void> connect({
    required String profile,
    required String remark,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (_attemptInProgress) throw const VpnConnectionBusyException();
    _attemptInProgress = true;
    try {
      await initialize();
      if (!await _engine.requestPermission()) {
        throw const VpnPermissionException();
      }

      final config = _toEngineConfig(profile);
      final connected = Completer<void>();
      var sawConnecting = false;
      final statusSubscription = statusChanges.listen((status) {
        final state = status.state.toUpperCase();
        if (state == 'CONNECTING') sawConnecting = true;
        if (state == 'CONNECTED' && !connected.isCompleted) {
          connected.complete();
        } else if ((state == 'ERROR' ||
                (state == 'DISCONNECTED' && sawConnecting)) &&
            !connected.isCompleted) {
          connected.completeError(const VpnConnectionException());
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
        await connected.future.timeout(timeout);
      } on TimeoutException {
        await _stopPreservingFailure();
        throw const VpnConnectionTimeoutException();
      } on VpnPermissionException {
        rethrow;
      } catch (_) {
        await _stopPreservingFailure();
        // Native/plugin exception messages can contain profile material.
        throw const VpnConnectionException();
      } finally {
        await statusSubscription.cancel();
      }
    } finally {
      _attemptInProgress = false;
    }
  }

  String _toEngineConfig(String profile) {
    final value = profile.trim();
    if (value.isEmpty) throw const FormatException('VPN profile is empty.');
    if (value.contains('://')) {
      return V2ray.parseFromURL(value).getFullConfiguration();
    }
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('VPN profile must be a JSON object or supported share link.');
    }
    return value;
  }

  Future<void> _stopPreservingFailure() async {
    try {
      await _engine.stopV2Ray();
    } catch (_) {
      // Do not replace the original connection error with a stop error.
    }
  }

  Future<void> disconnect() async {
    await initialize();
    await _engine.stopV2Ray();
  }
}

class VpnPermissionException implements Exception {
  const VpnPermissionException();
}

class VpnConnectionBusyException implements Exception {
  const VpnConnectionBusyException();
}

class VpnConnectionException implements Exception {
  const VpnConnectionException();
}

class VpnConnectionTimeoutException implements Exception {
  const VpnConnectionTimeoutException();
}
