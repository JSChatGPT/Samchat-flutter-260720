import 'dart:async';

/// Simple debounce helper for search input, typing indicators, etc.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// Fires immediately on first call, then suppresses further calls until
/// [cooldown] has elapsed — used for the typing-indicator "start" event so we
/// don't hammer the REST endpoint on every keystroke.
class RateLimiter {
  RateLimiter({required this.cooldown});

  final Duration cooldown;
  DateTime? _lastFired;

  bool tryFire() {
    final now = DateTime.now();
    if (_lastFired == null || now.difference(_lastFired!) >= cooldown) {
      _lastFired = now;
      return true;
    }
    return false;
  }

  void reset() => _lastFired = null;
}
