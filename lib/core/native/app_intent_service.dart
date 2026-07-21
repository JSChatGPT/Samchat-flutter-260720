import 'dart:async';

import 'app_intent_channel.dart';

/// Bridges MainActivity's launch/new intents (SMS notification tap, `sms:`
/// compose link, or a share-sheet SEND) into one broadcast stream — mirrors
/// PushService's `onNavigate` pattern for FCM notification taps.
class AppIntentService {
  final _controller = StreamController<AppIntent>.broadcast();
  StreamSubscription<AppIntent>? _sub;
  bool _ready = false;

  Stream<AppIntent> get onIntent => _controller.stream;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    final initial = await AppIntentChannel.consumeInitialIntent();
    if (initial != null) _controller.add(initial);
    _sub = AppIntentChannel.stream.listen(_controller.add);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
