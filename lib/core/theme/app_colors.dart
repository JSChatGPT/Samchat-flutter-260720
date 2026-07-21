import 'package:flutter/material.dart';

/// SamChat brand palette — ported 1:1 from the old_old reference app
/// (deep-orange accent, slate neutrals) so the new client matches its look.
class AppColors {
  AppColors._();

  // Brand — single accent hue (no separate teal secondary in the reference).
  static const Color seed = Color(0xFFFF5722);

  // Light
  static const Color lightPrimary = Color(0xFFFF5722);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color.fromRGBO(255, 87, 34, 0.08);
  static const Color lightOnPrimaryContainer = Color(0xFFE64A19);
  static const Color lightSecondary = Color(0xFFFF8A65);
  static const Color lightSecondaryContainer = Color.fromRGBO(255, 87, 34, 0.08);
  static const Color lightSurface = Color(0xFFF0F2F8);
  static const Color lightSurfaceContainerLow = Color(0xFFFFFFFF);
  static const Color lightOutlineVariant = Color.fromRGBO(0, 0, 0, 0.06);
  static const Color lightOnSurface = Color(0xFF0F172A);
  static const Color lightOnSurfaceVariant = Color(0xFF475569);
  static const Color lightAppBar = Color(0xFFFF5722);
  static const Color chatBackgroundLight = Color(0xFFF8FAFC);

  // Dark
  static const Color darkPrimary = Color(0xFFFF5722);
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkPrimaryContainer = Color.fromRGBO(255, 87, 34, 0.12);
  static const Color darkOnPrimaryContainer = Color(0xFFFF8A65);
  static const Color darkSecondary = Color(0xFFE64A19);
  static const Color darkSecondaryContainer = Color.fromRGBO(255, 87, 34, 0.12);
  static const Color darkSurface = Color(0xFF020617);
  static const Color darkSurfaceContainerLow = Color(0xFF1E293B);
  static const Color darkOutlineVariant = Color.fromRGBO(255, 255, 255, 0.06);
  static const Color darkOnSurface = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);
  static const Color darkAppBar = Color(0xFFE64A19);
  static const Color chatBackgroundDark = Color(0xFF0B1120);

  // Sent-message bubble gradient (top-left → bottom-right).
  static const List<Color> sentBubbleGradient = [Color(0xFFFF5722), Color(0xFFFF8A65)];

  // Fixed-meaning colors (kept conventional regardless of theme)
  static const Color online = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color tickRead = Color(0xFF38BDF8);
  static const Color tickDelivered = Color(0xFF94A3B8);
}
