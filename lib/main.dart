import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samchat_telecom/samchat_telecom.dart';

import 'app.dart';
import 'core/cache/chat_cache_service.dart';
import 'core/config/app_config.dart';
import 'core/providers/core_providers.dart';
import 'core/storage/local_prefs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await LocalPrefsService.create();
  final chatCache = await ChatCacheService.open();

  // Registers SamChat as a self-managed Telecom calling app (idempotent —
  // safe to call on every launch) and gives the native side the one thing
  // it can't otherwise know: AppConfig.apiBaseUrl, a Dart compile-time
  // constant, needed for the native-only decline HTTP call. Neither needs
  // login, so this doesn't wait for auth the way the token sync does.
  await SamchatTelecom.registerPhoneAccount();
  await SamchatTelecom.syncApiBaseUrl(AppConfig.apiBaseUrl);

  // Most screens sit under the orange AppBar, so light (white) status bar
  // icons are the app-wide default; the few screens with no AppBar
  // (splash, phone entry) override back to dark locally since they're on a
  // light background. Set explicitly rather than relying on AppBar's
  // per-screen auto-detection, which doesn't cover those screens.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        localPrefsServiceProvider.overrideWithValue(prefs),
        chatCacheServiceProvider.overrideWithValue(chatCache),
      ],
      child: const SamChatApp(),
    ),
  );
}


