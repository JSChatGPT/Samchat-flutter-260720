import '../../../models/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.currentUser,
    this.pendingPhoneNumber,
    this.pendingEmailHint,
  });

  final AuthStatus status;
  final AppUser? currentUser;

  /// Phone number awaiting OTP verification, kept between the phone-entry
  /// and OTP screens.
  final String? pendingPhoneNumber;

  /// Masked email address (e.g. "j***@gmail.com") returned by the backend
  /// when an email OTP was also sent alongside the SMS OTP.  Null when the
  /// user's account has no email or the backend did not send an email OTP.
  final String? pendingEmailHint;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? currentUser,
    String? pendingPhoneNumber,
    bool clearPendingPhoneNumber = false,
    String? pendingEmailHint,
    bool clearPendingEmailHint = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      currentUser: currentUser ?? this.currentUser,
      pendingPhoneNumber:
          clearPendingPhoneNumber ? null : (pendingPhoneNumber ?? this.pendingPhoneNumber),
      pendingEmailHint:
          clearPendingEmailHint ? null : (pendingEmailHint ?? this.pendingEmailHint),
    );
  }
}
