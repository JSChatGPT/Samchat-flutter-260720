import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_notifier.dart';

/// Runtime "is the app currently locked" state — separate from
/// [AppLockSettings] (the persisted on/off + timeout preference) because
/// toggling the setting mid-session must never lock the user out on the
/// spot; it should only take effect from the next background/foreground
/// cycle, exactly like WhatsApp.
///
/// Recreated fresh every app process, so its initial state naturally
/// reflects "locked at cold start if the feature is enabled" without any
/// extra bookkeeping.
final appLockGateProvider = StateNotifierProvider<AppLockGateNotifier, bool>((ref) {
  return AppLockGateNotifier(ref);
});

class AppLockGateNotifier extends StateNotifier<bool> {
  AppLockGateNotifier(this._ref) : super(_ref.read(appLockSettingsNotifierProvider).enabled);

  final Ref _ref;
  DateTime? _pausedAt;

  /// Call from the app-lifecycle observer when the app goes to background.
  void onPaused() {
    _pausedAt = DateTime.now();
  }

  /// Call from the app-lifecycle observer when the app returns to the
  /// foreground — re-locks if the selected timeout has elapsed since
  /// [onPaused]. "Immediately" has a zero duration, so any trip to the
  /// background at all re-locks, matching WhatsApp's "Immediately" option.
  void onResumed() {
    final settings = _ref.read(appLockSettingsNotifierProvider);
    final pausedAt = _pausedAt;
    _pausedAt = null;
    if (!settings.enabled || pausedAt == null) return;
    if (DateTime.now().difference(pausedAt) >= settings.timeout.duration) {
      state = true;
    }
  }

  /// Call after a successful biometric/device-credential prompt.
  void unlock() {
    state = false;
  }
}
