import 'package:flutter/material.dart';

/// Semantic color tokens for the Smart Budget Tracker.
///
/// Cobalt + Sky + Mint palette.
/// Designed for a friendly, modern and polished personal-finance experience.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand / Primary
  // ---------------------------------------------------------------------------

  static const Color primary = Color(0xFF3155D4);
  static const Color primaryLight = Color(0xFF4C6FE3);
  static const Color primaryDark = Color(0xFF2543AD);

  static const Color secondary = Color(0xFF159A9C);
  static const Color secondaryLight = Color(0xFF31B6B5);
  static const Color secondaryDark = Color(0xFF0E7779);

  static const Color accent = Color(0xFFF0A35E);

  // ---------------------------------------------------------------------------
  // Semantic Status Colors
  // ---------------------------------------------------------------------------

  static const Color success = Color(0xFF239B70);
  static const Color successLight = Color(0xFF43B98B);
  static const Color successDark = Color(0xFF197454);

  static const Color warning = Color(0xFFD89432);
  static const Color warningLight = Color(0xFFE9AA50);
  static const Color warningDark = Color(0xFFAE6D1F);

  static const Color error = Color(0xFFD65C62);
  static const Color errorLight = Color(0xFFE4777C);
  static const Color errorDark = Color(0xFFB8454B);

  static const Color info = Color(0xFF4A8CC7);

  static const Color safeGreen = success;
  static const Color warningOrange = warning;
  static const Color dangerRed = error;

  // ---------------------------------------------------------------------------
  // Light Theme
  // ---------------------------------------------------------------------------

  static const Color backgroundLight = Color(0xFFF6F8FC);

  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color surfaceContainerLight = Color(0xFFEEF2F8);

  static const Color surfaceContainerHighLight = Color(0xFFE2E8F2);

  static const Color cardLight = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Dark Theme
  // ---------------------------------------------------------------------------

  static const Color backgroundDark = Color(0xFF0B1020);

  static const Color surfaceDark = Color(0xFF11172A);

  static const Color surfaceContainerDark = Color(0xFF19223A);

  static const Color surfaceContainerHighDark = Color(0xFF222D49);

  static const Color cardDark = Color(0xFF151D32);

  // ---------------------------------------------------------------------------
  // Text — Light
  // ---------------------------------------------------------------------------

  static const Color textPrimaryLight = Color(0xFF182033);

  static const Color textSecondaryLight = Color(0xFF68738A);

  static const Color textTertiaryLight = Color(0xFF969EAF);

  static const Color textOnPrimaryLight = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Text — Dark
  // ---------------------------------------------------------------------------

  static const Color textPrimaryDark = Color(0xFFF4F7FF);

  static const Color textSecondaryDark = Color(0xFFAAB4C8);

  static const Color textTertiaryDark = Color(0xFF77839B);

  static const Color textOnPrimaryDark = Color(0xFFFFFFFF);

  // ---------------------------------------------------------------------------
  // Dividers / Outlines
  // ---------------------------------------------------------------------------

  static const Color dividerLight = Color(0xFFE1E6EF);

  static const Color outlineLight = Color(0xFFCFD6E2);

  static const Color dividerDark = Color(0xFF29344D);

  static const Color outlineDark = Color(0xFF3A4763);

  // ---------------------------------------------------------------------------
  // Category Colors
  // ---------------------------------------------------------------------------

  static const Color catFood = Color(0xFFE87568);

  static const Color catFuel = Color(0xFFE3A050);

  static const Color catShopping = Color(0xFFD0A747);

  static const Color catRent = Color(0xFF55A8B2);

  static const Color catEmi = Color(0xFF45A77F);

  static const Color catTravel = Color(0xFF5D82CF);

  static const Color catEntertainment = Color(0xFF846EB0);

  static const Color catHealth = Color(0xFFD27B9D);

  static const Color catEducation = Color(0xFF48A6A5);

  static const Color catGroceries = Color(0xFF51A276);

  static const Color catBills = Color(0xFFD76060);

  static const Color catOthers = Color(0xFF818B9B);

  // ---------------------------------------------------------------------------
  // Brand Containers
  // ---------------------------------------------------------------------------

  static const Color primaryContainerLight = Color(0xFFE8ECFC);

  static const Color primaryContainerDark = Color(0xFF202D60);

  static const Color secondaryContainerLight = Color(0xFFE1F4F3);

  static const Color secondaryContainerDark = Color(0xFF123B3D);

  // ---------------------------------------------------------------------------
  // Status Containers
  // ---------------------------------------------------------------------------

  static const Color successContainerLight = Color(0xFFE3F5ED);

  static const Color successContainerDark = Color(0xFF123A2E);

  static const Color warningContainerLight = Color(0xFFFFF1DD);

  static const Color warningContainerDark = Color(0xFF3B2C17);

  static const Color errorContainerLight = Color(0xFFFBE8E9);

  static const Color errorContainerDark = Color(0xFF3B1E21);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2543AD), Color(0xFF4C6FE3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF2543AD), Color(0xFF3155D4), Color(0xFF159A9C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x123155D4), Color(0x04159A9C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ---------------------------------------------------------------------------
  // Finance-Specific Colors
  // ---------------------------------------------------------------------------

  static const Color income = Color(0xFF239B70);

  static const Color expense = Color(0xFFD65C62);

  static const Color remaining = Color(0xFF3155D4);

  static const Color savings = Color(0xFF159A9C);

  static const Color neutralFinance = Color(0xFF68738A);
}
