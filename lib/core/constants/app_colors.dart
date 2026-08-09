import 'package:flutter/material.dart';

/// Semantic color tokens for the Smart Budget Tracker.
///
/// These are the single source of truth for statuses, surfaces, text and
/// category colors. Widgets should reference these tokens (or the theme
/// `ColorScheme`) rather than hard-coding hex values.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand / Primary palette (Modern Emerald & Teal)
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800
  static const Color secondary = Color(0xFF6366F1); // Indigo Accent
  static const Color secondaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFFF59E0B); // Amber Accent

  // ---------------------------------------------------------------------------
  // Semantic status colors
  // ---------------------------------------------------------------------------
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF97316);
  static const Color safeGreen = success;
  static const Color warningOrange = warning;
  static const Color dangerRed = error;

  // ---------------------------------------------------------------------------
  // Background & Surfaces (Light)
  // ---------------------------------------------------------------------------
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceContainerLight = Color(0xFFF1F5F9);
  static const Color surfaceContainerHighLight = Color(0xFFE2E8F0);
  static const Color cardLight = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Background & Surfaces (Dark) — intentional hierarchy, not inverted light
  // ---------------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF111A2E);
  static const Color surfaceContainerDark = Color(0xFF1B2740);
  static const Color surfaceContainerHighDark = Color(0xFF24324F);
  static const Color cardDark = Color(0xFF151F36);

  // ---------------------------------------------------------------------------
  // Text colors
  // ---------------------------------------------------------------------------
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // ---------------------------------------------------------------------------
  // Dividers / outlines
  // ---------------------------------------------------------------------------
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color dividerDark = Color(0xFF2A3A5C);
  static const Color outlineLight = Color(0xFFCBD5E1);
  static const Color outlineDark = Color(0xFF334155);

  // ---------------------------------------------------------------------------
  // Category colors
  // ---------------------------------------------------------------------------
  static const Color catFood = Color(0xFFFF6B6B);
  static const Color catFuel = Color(0xFFFF9F43);
  static const Color catShopping = Color(0xFFFECA57);
  static const Color catRent = Color(0xFF48DBFB);
  static const Color catEmi = Color(0xFF1DD1A1);
  static const Color catTravel = Color(0xFF54A0FF);
  static const Color catEntertainment = Color(0xFF5F27CD);
  static const Color catHealth = Color(0xFFFF9FF3);
  static const Color catEducation = Color(0xFF00D2D3);
  static const Color catGroceries = Color(0xFF10AC84);
  static const Color catBills = Color(0xFFEE5253);
  static const Color catOthers = Color(0xFF8395A7);

  // ---------------------------------------------------------------------------
  // Gradients (kept minimal and intentional)
  // ---------------------------------------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF0F766E), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x1A0F766E), Color(0x050F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
