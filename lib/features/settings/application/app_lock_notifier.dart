import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/storage/local_prefs_service.dart';

/// Matches WhatsApp's own "require after" choices exactly, per user request.
enum AppLockTimeout {
  immediately,
  after1Minute,
  after30Minutes;

  Duration get duration => switch (this) {
        AppLockTimeout.immediately => Duration.zero,
        AppLockTimeout.after1Minute => const Duration(minutes: 1),
        AppLockTimeout.after30Minutes => const Duration(minutes: 30),
      };

  String get label => switch (this) {
        AppLockTimeout.immediately => 'Immediately',
        AppLockTimeout.after1Minute => 'After 1 minute',
        AppLockTimeout.after30Minutes => 'After 30 minutes',
      };

  static AppLockTimeout fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => AppLockTimeout.immediately);
}

class AppLockSettings {
  const AppLockSettings({required this.enabled, required this.timeout});

  final bool enabled;
  final AppLockTimeout timeout;

  AppLockSettings copyWith({bool? enabled, AppLockTimeout? timeout}) => AppLockSettings(
        enabled: enabled ?? this.enabled,
        timeout: timeout ?? this.timeout,
      );
}

/// Persisted fingerprint-lock preference — see LocalPrefsService. Purely
/// local/device-level; nothing here talks to the backend.
final appLockSettingsNotifierProvider = StateNotifierProvider<AppLockSettingsNotifier, AppLockSettings>((ref) {
  return AppLockSettingsNotifier(ref.watch(localPrefsServiceProvider));
});

class AppLockSettingsNotifier extends StateNotifier<AppLockSettings> {
  AppLockSettingsNotifier(this._prefs)
      : super(AppLockSettings(
          enabled: _prefs.appLockEnabled,
          timeout: AppLockTimeout.fromName(_prefs.appLockTimeout),
        ));

  final LocalPrefsService _prefs;

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _prefs.setAppLockEnabled(value);
  }

  Future<void> setTimeout(AppLockTimeout value) async {
    state = state.copyWith(timeout: value);
    await _prefs.setAppLockTimeout(value.name);
  }
}
