import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

enum SocketConnectionState { disconnected, connecting, connected, reconnecting }

/// A single frame off the Pusher wire protocol, with `data` already decoded
/// from its (often double-JSON-encoded) string form into a Map.
class PusherFrame {
  const PusherFrame({required this.event, this.channel, required this.data});

  final String event;
  final String? channel;
  final Map<String, dynamic> data;
}

/// Minimal client for the Pusher websocket wire protocol (protocol version 7).
/// Talks to real Pusher Channels (pusher.com) — this backend previously
/// self-hosted Laravel Reverb (which speaks the same wire protocol) but has
/// since switched to Pusher Cloud to avoid running its own websocket server;
/// this client didn't need to change, only the host/key it points at
/// (see AppConfig.pusherWsHost/pusherAppKey). We hand-roll this instead of
/// using `pusher_channels_flutter` because that package's public Dart API
/// had no way to target a self-hosted host:port back when this backend still
/// ran Reverb (see core/realtime/pusher_service.dart doc comment).
///
/// Handles: connection handshake, subscribe/unsubscribe framing, ping/pong
/// keep-alive, and automatic reconnect with exponential backoff. Does NOT
/// know about HTTP auth (`/broadcasting/auth`) — the caller supplies
/// `auth`/`channelData` strings already fetched, keeping this class
/// dependency-free of Dio/auth concerns.
class PusherProtocolClient {
  PusherProtocolClient({
    required this.host,
    required this.port,
    required this.appKey,
    required this.useTls,
  });

  final String host;
  final int port;
  final String appKey;
  final bool useTls;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manuallyDisconnected = false;

  String? socketId;
  Duration _activityTimeout = const Duration(seconds: 100);
  final Duration _pongTimeout = const Duration(seconds: 30);

  SocketConnectionState _state = SocketConnectionState.disconnected;
  SocketConnectionState get state => _state;

  final _stateController = StreamController<SocketConnectionState>.broadcast();
  Stream<SocketConnectionState> get onStateChange => _stateController.stream;

  final _frameController = StreamController<PusherFrame>.broadcast();
  Stream<PusherFrame> get onFrame => _frameController.stream;

  final _socketIdReadyController = StreamController<String>.broadcast();
  Stream<String> get onSocketIdReady => _socketIdReadyController.stream;

  void connect() {
    _manuallyDisconnected = false;
    // Idempotent: never stack a second socket on top of a live one. connect()
    // is invoked from more than one place (session restore, login, app resume)
    // and a duplicate WebSocket would double-deliver every frame — which shows
    // up as duplicate WebRTC offers/answers and glare that intermittently
    // wedges a call on "connecting".
    if (_channel != null &&
        (_state == SocketConnectionState.connected ||
            _state == SocketConnectionState.connecting ||
            _state == SocketConnectionState.reconnecting)) {
      return;
    }
    _openSocket();
  }

  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _teardownSocket();
    _setState(SocketConnectionState.disconnected);
  }

  void _openSocket() {
    // Defensively drop any half-open socket/subscription first so we can never
    // leak a listener that keeps delivering duplicate frames.
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _setState(_reconnectAttempts == 0
        ? SocketConnectionState.connecting
        : SocketConnectionState.reconnecting);
    final scheme = useTls ? 'wss' : 'ws';
    final uri = Uri.parse(
      '$scheme://$host:$port/app/$appKey?protocol=7&client=samchat-flutter&version=1.0&flash=false',
    );
    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      // `connect()` returns immediately; connection failures (e.g. refused,
      // unreachable) only surface via `.ready`, NOT necessarily via the
      // stream — an unawaited rejection there is reported as an unhandled
      // Future error rather than driving reconnect, so it must be caught
      // explicitly. Both `.ready` and the stream can fire for the same
      // failed attempt, so dedupe with a per-attempt flag.
      var handled = false;
      void handleFailure() {
        if (handled || !identical(_channel, channel)) return;
        handled = true;
        _handleDisconnect();
      }

      channel.ready.then((_) {}, onError: (_) => handleFailure());
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onError: (_) => handleFailure(),
        onDone: handleFailure,
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleRawMessage(dynamic raw) {
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final event = frame['event'] as String?;
    if (event == null) return;
    final channel = frame['channel'] as String?;
    final rawData = frame['data'];
    final data = _decodeData(rawData);

    switch (event) {
      case 'pusher:connection_established':
        socketId = data['socket_id'] as String?;
        final activityMs = data['activity_timeout'];
        if (activityMs is num) {
          _activityTimeout = Duration(seconds: activityMs.toInt());
        }
        _reconnectAttempts = 0;
        _setState(SocketConnectionState.connected);
        _resetPingTimer();
        if (socketId != null) _socketIdReadyController.add(socketId!);
        return;
      case 'pusher:ping':
        _sendRaw({'event': 'pusher:pong', 'data': {}});
        return;
      case 'pusher:pong':
        _pongTimeoutTimer?.cancel();
        return;
      case 'pusher:error':
        // Surfaced as a generic frame too, so callers can inspect it if needed.
        break;
    }
    _resetPingTimer();
    _frameController.add(PusherFrame(event: event, channel: channel, data: data));
  }

  Map<String, dynamic> _decodeData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) return rawData;
    if (rawData is String) {
      try {
        final decoded = jsonDecode(rawData);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // Not JSON — leave as empty map, callers that need the raw string
        // should read PusherFrame before this decode step if ever needed.
      }
    }
    return const {};
  }

  void subscribe({required String channelName, String? auth, String? channelData}) {
    final data = <String, dynamic>{'channel': channelName};
    if (auth != null) data['auth'] = auth;
    if (channelData != null) data['channel_data'] = channelData;
    _sendRaw({'event': 'pusher:subscribe', 'data': data});
  }

  void unsubscribe(String channelName) {
    _sendRaw({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
  }

  void _sendRaw(Map<String, dynamic> frame) {
    final channel = _channel;
    if (channel == null || _state != SocketConnectionState.connected) return;
    try {
      channel.sink.add(jsonEncode(frame));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _resetPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer(_activityTimeout, () {
      _sendRaw({'event': 'pusher:ping', 'data': {}});
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = Timer(_pongTimeout, _handleDisconnect);
    });
  }

  void _handleDisconnect() {
    if (_state == SocketConnectionState.disconnected && _manuallyDisconnected) return;
    _teardownSocket();
    if (_manuallyDisconnected) {
      _setState(SocketConnectionState.disconnected);
      return;
    }
    _setState(SocketConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final seconds = (1 << (_reconnectAttempts.clamp(0, 5))).clamp(1, 30);
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_manuallyDisconnected) _openSocket();
    });
  }

  void _teardownSocket() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    socketId = null;
  }

  void _setState(SocketConnectionState state) {
    _state = state;
    _stateController.add(state);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _teardownSocket();
    _stateController.close();
    _frameController.close();
    _socketIdReadyController.close();
  }
}
