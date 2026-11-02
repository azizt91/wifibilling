import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6A5ACD); // SlateBlue
  static const Color primaryDark = Color(0xFF5A4BAF);
  static const Color primaryLight = Color(0xFF8A7AED);

  // Secondary Colors
  static const Color secondary = Color(0xFF6C757D);
  static const Color secondaryLight = Color(0xFF9CA3AF);

  // Status Colors
  static const Color success = Color(0xFF28A745);
  static const Color successLight = Color(0xFFD4EDDA);
  static const Color danger = Color(0xFFDC3545);
  static const Color dangerLight = Color(0xFFF8D7DA);
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFF3CD);
  static const Color info = Color(0xFF17A2B8);
  static const Color infoLight = Color(0xFFD1ECF1);

  // Background Colors
  static const Color background = Color(0xFFF8F9FE);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF2D2D44);

  // Text Colors
  static const Color textPrimary = Color(0xFF343A40);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);

  // Border Colors
  static const Color border = Color(0xFFE9ECEF);
  static const Color borderDark = Color(0xFF4A4A6A);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF28A745), Color(0xFF20C997)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC3545), Color(0xFFC82333)],
  );

  // Shadow Colors
  static Color shadow = Colors.black.withOpacity(0.05);
  static Color shadowMedium = Colors.black.withOpacity(0.1);
  static Color shadowDark = Colors.black.withOpacity(0.2);

  // Shimmer Colors
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF6A5ACD),
    Color(0xFF28A745),
    Color(0xFFFFC107),
    Color(0xFFDC3545),
    Color(0xFF17A2B8),
    Color(0xFF6C757D),
    Color(0xFFFF6384),
    Color(0xFF36A2EB),
    Color(0xFFFFCE56),
    Color(0xFF4BC0C0),
  ];
}
