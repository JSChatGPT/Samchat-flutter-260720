import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a Stream (here, [StateNotifier.stream] from auth state) into the
/// `Listenable` go_router's `refreshListenable` expects, so route redirects
/// re-evaluate whenever auth status changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
