import 'dart:async';

import 'package:dio/dio.dart';

import '../api/endpoints.dart';
import '../config/app_config.dart';
import '../realtime/pusher_service.dart';

/// Mobile-specific presence: the web client relies entirely on the `app`
/// presence channel, but per API_DOCUMENTATION.md §3, mobile clients must
/// actively call `POST /user/online` on foreground and periodically while
/// active instead. Driven by app lifecycle changes from `app.dart`.
class HeartbeatService {
  HeartbeatService({required Dio dio, required PusherService pusher})
      : _dio = dio,
        _pusher = pusher;

  final Dio _dio;
  final PusherService _pusher;
  Timer? _timer;

  void onResumed() {
    _pusher.ensureConnected();
    _beat();
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.onlineHeartbeatInterval, (_) => _beat());
  }

  void onPaused() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _beat() async {
    try {
      await _dio.post(Endpoints.heartbeat);
    } catch (_) {
      // Best-effort — a missed heartbeat just means the next one, or the
      // next `GET .../online-status` poll elsewhere, catches us up.
    }
  }

  void dispose() => _timer?.cancel();
}
