import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary & Gradient Accent Palette (Modern Emerald & Teal Theme)
  static const Color primary = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800
  static const Color secondary = Color(0xFF6366F1); // Indigo Accent
  static const Color secondaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFFF59E0B); // Amber Accent

  // Safe Spending Status Indicators
  static const Color safeGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color dangerRed = Color(0xFFEF4444);

  // Background & Surfaces (Light)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Background & Surfaces (Dark)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color cardDark = Color(0xFF1E293B);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Category Colors
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

  // Gradient definitions
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
