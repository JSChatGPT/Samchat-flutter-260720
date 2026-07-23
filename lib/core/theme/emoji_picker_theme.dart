import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Themed `Config` for every `EmojiPicker` in the app (composer + reaction
/// picker) — the package defaults to its own blue/light styling regardless
/// of app theme, which read as visibly out of place next to the rest of the
/// orange-accented, light/dark-aware UI. Single source of truth so the
/// composer's picker and the reaction picker never drift from each other.
Config emojiPickerConfig(ColorScheme scheme, {double height = 256}) {
  return Config(
    height: height,
    emojiViewConfig: EmojiViewConfig(
      backgroundColor: scheme.surface,
      columns: 8,
      emojiSizeMax: 26,
      buttonMode: ButtonMode.MATERIAL,
    ),
    categoryViewConfig: CategoryViewConfig(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primary,
      iconColorSelected: scheme.primary,
      iconColor: scheme.onSurfaceVariant,
      backspaceColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
    ),
    bottomActionBarConfig: BottomActionBarConfig(
      backgroundColor: scheme.surfaceContainerLow,
      buttonColor: scheme.primary,
      buttonIconColor: scheme.onPrimary,
    ),
    searchViewConfig: SearchViewConfig(
      backgroundColor: scheme.surface,
      buttonIconColor: scheme.onSurfaceVariant,
      hintTextStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
  );
}
