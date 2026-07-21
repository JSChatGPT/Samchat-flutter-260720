import 'package:local_auth/local_auth.dart';

/// Thin wrapper over `local_auth` — the only thing the rest of the app needs
/// to know about biometrics. Falls back to the device's own PIN/pattern/
/// password if no biometric is enrolled (biometricOnly: false), the same
/// way WhatsApp's "fingerprint lock" accepts the phone's regular unlock
/// method as a fallback.
class BiometricAuthService {
  final _auth = LocalAuthentication();

  Future<bool> get isSupported async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
