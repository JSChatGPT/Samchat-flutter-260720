import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import 'app_lock_notifier.dart';

/// Requires a fingerprint/face/device-credential confirmation before a
/// sensitive in-app action (sending a payment, linking a wallet) — but only
/// when the user has turned on fingerprint lock in Settings > Privacy.
/// Returns true immediately, with no prompt, if the feature is off: the user
/// never opted into requiring it for anything short of opening the app.
Future<bool> confirmWithBiometricIfEnabled(WidgetRef ref, {required String reason}) async {
  final enabled = ref.read(appLockSettingsNotifierProvider).enabled;
  if (!enabled) return true;
  return ref.read(biometricAuthServiceProvider).authenticate(reason: reason);
}
