import '../../../models/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.currentUser, this.pendingPhoneNumber});

  final AuthStatus status;
  final AppUser? currentUser;

  /// Phone number awaiting OTP verification, kept between the phone-entry
  /// and OTP screens.
  final String? pendingPhoneNumber;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? currentUser,
    String? pendingPhoneNumber,
    bool clearPendingPhoneNumber = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      currentUser: currentUser ?? this.currentUser,
      pendingPhoneNumber:
          clearPendingPhoneNumber ? null : (pendingPhoneNumber ?? this.pendingPhoneNumber),
    );
  }
}
