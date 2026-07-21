import 'dart:async';

/// Decouples the Dio interceptor (which has no business depending on
/// Riverpod's AuthNotifier) from the auth layer: the interceptor fires
/// [notifyUnauthorized] on a bare 401, and AuthNotifier subscribes to react
/// (clear token, disconnect realtime, redirect to the auth stack).
class SessionController {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onUnauthorized => _controller.stream;

  void notifyUnauthorized() => _controller.add(null);

  void dispose() => _controller.close();
}
