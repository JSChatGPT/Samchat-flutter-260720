import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/session_controller.dart';
import '../cache/chat_cache_service.dart';
import '../crypto/e2ee_repository.dart';
import '../crypto/e2ee_service.dart';
import '../native/app_intent_channel.dart';
import '../native/app_intent_service.dart';
import '../push/local_notifications_service.dart';
import '../push/push_service.dart';
import '../realtime/pusher_service.dart';
import '../security/biometric_auth_service.dart';
import '../storage/local_prefs_service.dart';
import '../storage/secure_storage_service.dart';
import 'heartbeat_service.dart';

/// [LocalPrefsService] needs async init (SharedPreferences.getInstance()) —
/// main() awaits it and overrides this provider before runApp, so every
/// other provider can just `ref.watch` it synchronously.
final localPrefsServiceProvider = Provider<LocalPrefsService>((ref) {
  throw UnimplementedError('localPrefsServiceProvider must be overridden in main()');
});

/// [ChatCacheService] needs async init (sqflite's `openDatabase`) — same
/// pattern as [localPrefsServiceProvider] above.
final chatCacheServiceProvider = Provider<ChatCacheService>((ref) {
  throw UnimplementedError('chatCacheServiceProvider must be overridden in main()');
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

final sessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController();
  ref.onDispose(controller.dispose);
  return controller;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    storage: ref.watch(secureStorageServiceProvider),
    session: ref.watch(sessionControllerProvider),
  );
});

final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);

/// App-lifetime — created once, connected after login, never autoDisposed.
final pusherServiceProvider = Provider<PusherService>((ref) {
  final service = PusherService(storage: ref.watch(secureStorageServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

final localNotificationsServiceProvider = Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});

final pushServiceProvider = Provider<PushService>((ref) {
  final service = PushService(
    dio: ref.watch(dioProvider),
    notifications: ref.watch(localNotificationsServiceProvider),
    prefs: ref.watch(localPrefsServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final heartbeatServiceProvider = Provider<HeartbeatService>((ref) {
  final service = HeartbeatService(dio: ref.watch(dioProvider), pusher: ref.watch(pusherServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

final e2eeRepositoryProvider = Provider<E2eeRepository>((ref) {
  return E2eeRepository(ref.watch(dioProvider));
});

/// App-lifetime — device keypair/identity persists for the session; chat
/// keys are cached in memory + secure storage across chats as they're used.
final e2eeServiceProvider = Provider<E2eeService>((ref) {
  return E2eeService(
    storage: ref.watch(secureStorageServiceProvider),
    repository: ref.watch(e2eeRepositoryProvider),
  );
});

/// Whether a chat currently has an E2EE key on this device — drives the lock
/// icon in the chat header. False (not an error) whenever the key hasn't
/// finished distributing yet or the chat predates E2EE.
final chatIsEncryptedProvider = FutureProvider.autoDispose.family<bool, String>((ref, chatId) async {
  return await ref.watch(e2eeServiceProvider).getChatKey(chatId) != null;
});

/// Notification-tap navigation targets (message / incoming_call) — a widget
/// near the app root listens to this and drives the router.
final pushNavigationStreamProvider = StreamProvider<PushNavigationTarget>((ref) {
  return ref.watch(pushServiceProvider).onNavigate;
});

/// SMS notification taps, `sms:` compose links, and share-sheet SEND intents
/// from MainActivity — see core/native/app_intent_service.dart.
final appIntentServiceProvider = Provider<AppIntentService>((ref) {
  final service = AppIntentService();
  service.init();
  ref.onDispose(service.dispose);
  return service;
});

final appIntentStreamProvider = StreamProvider<AppIntent>((ref) {
  return ref.watch(appIntentServiceProvider).onIntent;
});
