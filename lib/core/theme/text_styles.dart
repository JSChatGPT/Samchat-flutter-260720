import 'package:flutter/material.dart';

/// Inter, bundled locally as a variable font asset (assets/fonts) rather than
/// fetched at runtime via google_fonts — the app must work on networks that
/// can reach only the local API host, not the public internet.
class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Inter';

  static TextTheme textTheme(ColorScheme scheme) {
    TextStyle style(double size, FontWeight weight, {Color? color, double? letterSpacing}) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color ?? scheme.onSurface,
      );
    }

    return TextTheme(
      headlineSmall: style(22, FontWeight.w700, letterSpacing: -0.2),
      titleLarge: style(20, FontWeight.w700, letterSpacing: -0.2),
      titleMedium: style(16, FontWeight.w600),
      titleSmall: style(14, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400),
      bodyMedium: style(15, FontWeight.w400),
      bodySmall: style(12, FontWeight.w400, color: scheme.onSurfaceVariant),
      labelLarge: style(14, FontWeight.w600),
    );
  }
}
