import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:samchat_flutter/app.dart';
import 'package:samchat_flutter/core/cache/chat_cache_service.dart';
import 'package:samchat_flutter/core/providers/core_providers.dart';
import 'package:samchat_flutter/core/storage/local_prefs_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App boots to the splash screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await LocalPrefsService.create();
    final cache = await ChatCacheService.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localPrefsServiceProvider.overrideWithValue(prefs),
          chatCacheServiceProvider.overrideWithValue(cache),
        ],
        child: const SamChatApp(),
      ),
    );

    expect(find.text('Samchat'), findsOneWidget);
  });
}
