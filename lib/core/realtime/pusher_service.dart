import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'pusher_protocol_client.dart';
import 'realtime_events.dart';

/// High-level realtime service used by the rest of the app. Wraps
/// [PusherProtocolClient] (the raw wire-protocol implementation) and adds:
/// - fetching channel auth from `POST /broadcasting/auth` for private channels
/// - tracking active subscriptions and re-authenticating/re-subscribing them
///   after a reconnect (socket_id changes on every reconnect, so private
///   channel auth signatures must be refreshed)
/// - a single broadcast [events] stream the rest of the app filters by
///   channel/event name, mirroring how the plugin-based design would have
///   funneled everything through one `onEvent` callback.
///
/// We talk to Pusher Channels directly over our own HTTP client here (not the
/// shared [ApiClient]'s Dio, to avoid a dependency cycle with auth/session
/// wiring — this only ever calls one endpoint) but reuses the same base URL
/// + token.
class PusherService {
  PusherService({required SecureStorageService storage}) : _storage = storage {
    _client = PusherProtocolClient(
      host: AppConfig.pusherWsHost,
      port: AppConfig.pusherWsPort,
      appKey: AppConfig.pusherAppKey,
      useTls: AppConfig.pusherUseTls,
    );
    _authDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, headers: {'Accept': 'application/json'}));
    _client.onStateChange.listen(_onStateChange);
    _client.onFrame.listen(_onFrame);
    _client.onSocketIdReady.listen((_) => _resubscribeAll());
  }

  final SecureStorageService _storage;
  late final PusherProtocolClient _client;
  late final Dio _authDio;

  final Set<String> _activeChannels = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, int> _retryAttempts = {};

  final _eventsController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _eventsController.stream;

  final _connectionStateController = StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get connectionState => _connectionStateController.stream;

  SocketConnectionState get currentState => _client.state;

  void connect() => _client.connect();

  void disconnect() {
    _activeChannels.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _retryAttempts.clear();
    _client.disconnect();
  }

  Future<void> subscribe(String channelName) async {
    _activeChannels.add(channelName);
    _retryTimers.remove(channelName)?.cancel();
    _retryAttempts.remove(channelName);
    if (_client.state != SocketConnectionState.connected) return;
    await _subscribeNow(channelName);
  }

  Future<void> unsubscribe(String channelName) async {
    _activeChannels.remove(channelName);
    _retryTimers.remove(channelName)?.cancel();
    _retryAttempts.remove(channelName);
    _client.unsubscribe(channelName);
  }

  Future<void> _resubscribeAll() async {
    for (final channel in _activeChannels.toList()) {
      await _subscribeNow(channel);
    }
  }

  Future<void> _subscribeNow(String channelName) async {
    final isPrivate = channelName.startsWith('private-') || channelName.startsWith('presence-');
    if (!isPrivate) {
      _client.subscribe(channelName: channelName);
      return;
    }
    final socketId = _client.socketId;
    if (socketId == null) return;
    try {
      final token = await _storage.readToken();
      final response = await _authDio.post(
        '/broadcasting/auth',
        data: {'channel_name': channelName, 'socket_id': socketId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        ),
      );
      final data = response.data as Map<String, dynamic>;
      _client.subscribe(
        channelName: channelName,
        auth: data['auth'] as String?,
        channelData: data['channel_data'] as String?,
      );
      _retryTimers.remove(channelName)?.cancel();
      _retryAttempts.remove(channelName);
    } catch (e) {
      // Auth failed (token dead, network blip) — the auth interceptor path
      // for the main API client handles global 401 logout; here we schedule
      // a backed-off retry rather than silently abandoning the channel until
      // the next full reconnect (which may never come if the socket stays
      // up), since a single transient failure — e.g. right after app start,
      // before secure storage / the auth token is fully warmed up — used to
      // permanently kill delivery on that channel for the rest of the
      // session with zero visibility.
      _scheduleRetry(channelName);
    }
  }

  void _scheduleRetry(String channelName) {
    if (!_activeChannels.contains(channelName)) return;
    _retryTimers.remove(channelName)?.cancel();
    final attempt = (_retryAttempts[channelName] ?? 0) + 1;
    _retryAttempts[channelName] = attempt;
    final seconds = (1 << attempt.clamp(0, 5)).clamp(2, 30);
    _retryTimers[channelName] = Timer(Duration(seconds: seconds), () {
      _retryTimers.remove(channelName);
      if (_client.state == SocketConnectionState.connected && _activeChannels.contains(channelName)) {
        _subscribeNow(channelName);
      }
    });
  }

  void _onStateChange(SocketConnectionState state) {
    _connectionStateController.add(state);
  }

  void _onFrame(PusherFrame frame) {
    if (frame.channel == null) return;
    _eventsController.add(
      RealtimeEvent(channelName: frame.channel!, eventName: frame.event, data: frame.data),
    );
  }

  /// Call from a `WidgetsBindingObserver.didChangeAppLifecycleState` when the
  /// app resumes — ensures we're connected and re-authed rather than sitting
  /// on a stale socket the OS may have silently dropped in the background.
  void ensureConnected() {
    if (_client.state == SocketConnectionState.disconnected) {
      _client.connect();
    }
  }

  void dispose() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    _client.dispose();
    _eventsController.close();
    _connectionStateController.close();
  }
}
