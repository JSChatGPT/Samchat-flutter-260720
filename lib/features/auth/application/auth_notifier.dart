import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/session_controller.dart';
import '../../../core/cache/chat_cache_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/push/push_service.dart';
import '../../../core/realtime/pusher_service.dart';
import '../../../core/realtime/realtime_events.dart';
import '../../../core/storage/local_prefs_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../models/user.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

/// The signed-in user, or null. Cheap convenience wrapper around
/// [authNotifierProvider] for widgets that only need identity, not status.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authNotifierProvider).currentUser;
});

final currentUserIdProvider = Provider<String>((ref) {
  return ref.watch(currentUserProvider)?.id ?? '';
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    repository: ref.watch(authRepositoryProvider),
    storage: ref.watch(secureStorageServiceProvider),
    prefs: ref.watch(localPrefsServiceProvider),
    session: ref.watch(sessionControllerProvider),
    pusher: ref.watch(pusherServiceProvider),
    push: ref.watch(pushServiceProvider),
    cache: ref.watch(chatCacheServiceProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({
    required this.repository,
    required this.storage,
    required this.prefs,
    required this.session,
    required this.pusher,
    required this.push,
    required this.cache,
  }) : super(const AuthState()) {
    session.onUnauthorized.listen((_) => _forceLogout());
    _restoreSession();
  }

  final AuthRepository repository;
  final SecureStorageService storage;
  final LocalPrefsService prefs;
  final SessionController session;
  final PusherService pusher;
  final PushService push;
  final ChatCacheService cache;

  /// Cache-first: a stored token plus a cached profile is enough to enter
  /// the authenticated UI immediately, without waiting on (or depending
  /// the app's entire usability on) a `GET /user` round trip — the
  /// background call below still runs to refresh the profile and confirm
  /// the token is genuinely still valid, it just no longer gates entry.
  ///
  /// Critically, a failure from that background call only forces a logout
  /// when it's a real rejection (`ApiException.isUnauthorized`, i.e. the
  /// server actually said 401) — never for a plain connectivity failure.
  /// Every *other* authenticated request in the app already gets this
  /// exact right via AuthInterceptor -> SessionController.onUnauthorized
  /// (see the constructor above); this was the one call site that instead
  /// treated "couldn't reach the server" the same as "token rejected,"
  /// which logged the user out of a perfectly valid session just for
  /// opening the app offline — also defeating the point of the local chat
  /// cache, since the router redirects anyone `unauthenticated` straight to
  /// the login screen before they'd ever see it.
  Future<void> _restoreSession() async {
    final token = await storage.readToken();
    if (token == null || token.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final cachedUser = await storage.readCachedUser();
    if (cachedUser != null) {
      state = state.copyWith(status: AuthStatus.authenticated, currentUser: cachedUser);
      pusher.connect();
      pusher.subscribe(RealtimeChannels.user(cachedUser.id));
      push.init();
    }

    try {
      final user = await repository.me();
      await storage.writeCachedUser(user);
      state = state.copyWith(status: AuthStatus.authenticated, currentUser: user);
      if (cachedUser == null) {
        pusher.connect();
        pusher.subscribe(RealtimeChannels.user(user.id));
        push.init();
      }
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _forceLogout();
        return;
      }
      // Anything else (no connectivity, timeout, 5xx): if the cache branch
      // above already painted a profile, leave it exactly as-is. Only when
      // there was nothing to fall back to (e.g. the very first restore
      // since this device last logged in, before any profile was ever
      // cached) does this degrade to the old behavior of not entering the
      // app — there's genuinely nothing to show either way.
      if (cachedUser == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    }
  }

  Future<void> register({
    required String firstName,
    String? middleName,
    required String lastName,
    required String username,
    required String phoneNumber,
    String? email,
  }) {
    return repository.register(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      username: username,
      phoneNumber: phoneNumber,
      email: email,
    );
  }

  Future<void> requestOtp(String phoneNumber) async {
    final result = await repository.requestOtp(phoneNumber);
    state = state.copyWith(
      pendingPhoneNumber: phoneNumber,
      pendingEmailHint: result.emailHint,
      // If no email was sent, explicitly clear any stale hint from a prior
      // request so the OTP screen never shows a leftover address.
      clearPendingEmailHint: !result.emailSent,
    );
  }

  Future<void> verifyOtp(String otp) async {
    final phone = state.pendingPhoneNumber;
    if (phone == null) throw ApiException(message: 'No phone number pending verification.');
    final result = await repository.verifyOtp(phoneNumber: phone, otp: otp);
    await storage.writeToken(result.token);
    await storage.writeUserId(result.user.id);
    await storage.writeCachedUser(result.user);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      currentUser: result.user,
      clearPendingPhoneNumber: true,
      clearPendingEmailHint: true,
    );
    pusher.connect();
    pusher.subscribe(RealtimeChannels.user(result.user.id));
    push.init();
  }

  void updateCurrentUser(AppUser user) {
    state = state.copyWith(currentUser: user);
    unawaited(storage.writeCachedUser(user));
  }

  Future<void> logout() async {
    try {
      await repository.logout();
    } on ApiException {
      // Best-effort — proceed with local logout regardless.
    }
    await _forceLogout();
  }

  Future<void> _forceLogout() async {
    await push.unregister();
    pusher.disconnect();
    await storage.clear();
    await prefs.clear();
    // A different account signing into the same device must never see the
    // previous account's cached chats/messages.
    await cache.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
