import 'package:flutter/material.dart';

/// Shared design tokens for the Rib 9 Scanner app.
abstract final class AppColors {
  // Main app surfaces
  static const bgDeep = Color(0xFFF5F7FA);
  static const bgBase = Color(0xFFF8FAFC);

  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFF9FAFB);
  static const surfaceGlass = Color(0xFFFFFFFF);

  // Borders / dividers
  static const border = Color(0xFFDDE3EA);
  static const borderStrong = Color(0xFFCBD3DD);

  // Text
  static const textPrimary = Color(0xFF182235);
  static const textSecondary = Color(0xFF536176);
  static const textMuted = Color(0xFF8491A3);

  // Primary clinical accent
  static const accent = Color(0xFF275BB5);
  static const accentBlue = Color(0xFF3568C8);
  static const accentPurple = Color(0xFF5A67A8);

  // Status
  static const pass = Color(0xFF2E8B57);
  static const passDark = Color(0xFF216B42);

  static const fail = Color(0xFFC84646);
  static const failDark = Color(0xFFA93232);

  static const review = Color(0xFFC58A2A);
  static const reviewDark = Color(0xFF9A691B);

  // Segmentation overlay colors
  static const lungBlue = Color(0xFF4F83CC);
  static const ribRed = Color(0xFFD95F59);
  static const overlapMagenta = Color(0xFF8A67A5);
}

abstract final class AppGradients {
  static const accent = LinearGradient(
    colors: [
      Color(0xFF3568C8),
      Color(0xFF275BB5),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentVertical = LinearGradient(
    colors: [
      Color(0xFF3568C8),
      Color(0xFF275BB5),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient passGlow(Color c) => LinearGradient(
        colors: [
          c.withValues(alpha: 0.08),
          c.withValues(alpha: 0.02),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const cardSurface = LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppDecorations {
  static BoxDecoration glass({
    Color? borderColor,
    double radius = 10,
    List<Color>? gradientColors,
  }) {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxShadow glow(Color color, {double blur = 32}) => BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );
}

abstract final class AppTextStyles {
  static const display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static const sectionLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
  );

  static const caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );
}