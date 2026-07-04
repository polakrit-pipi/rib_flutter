import 'package:flutter/material.dart';

/// Shared design tokens for the Rib 9 Scanner app.
abstract final class AppColors {
  static const bgDeep = Color(0xFF060D18);
  static const bgBase = Color(0xFF0A1628);
  static const surface = Color(0xFF111E2E);
  static const surfaceElevated = Color(0xFF1A2A3D);
  static const surfaceGlass = Color(0xCC152030);

  static const textPrimary = Color(0xFFF0F7FC);
  static const textSecondary = Color(0xFF94AFC4);
  static const textMuted = Color(0xFF5A7590);

  static const accent = Color(0xFF00E5D4);
  static const accentBlue = Color(0xFF3B9EFF);
  static const accentPurple = Color(0xFF8B7CFF);

  static const pass = Color(0xFF00E676);
  static const passDark = Color(0xFF00A152);
  static const fail = Color(0xFFFF5252);
  static const failDark = Color(0xFFD32F2F);
  static const review = Color(0xFFFFB74D);
  static const reviewDark = Color(0xFFE65100);

  static const lungBlue = Color(0xFF2196F3);
  static const ribRed = Color(0xFFFF5252);
  static const overlapMagenta = Color(0xFFE040FB);
}

abstract final class AppGradients {
  static const accent = LinearGradient(
    colors: [Color(0xFF00E5D4), Color(0xFF3B9EFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentVertical = LinearGradient(
    colors: [Color(0xFF00E5D4), Color(0xFF0099E5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient passGlow(Color c) => LinearGradient(
        colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.05)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const cardSurface = LinearGradient(
    colors: [Color(0xFF1E3048), Color(0xFF142030)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class AppDecorations {
  static BoxDecoration glass({
    Color? borderColor,
    double radius = 24,
    List<Color>? gradientColors,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        colors: gradientColors ??
            [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: (borderColor ?? Colors.white).withValues(alpha: 0.12),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxShadow glow(Color color, {double blur = 32}) => BoxShadow(
        color: color.withValues(alpha: 0.28),
        blurRadius: blur,
        spreadRadius: 0,
      );
}

abstract final class AppTextStyles {
  static const display = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  static const sectionLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  static const body = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 14,
    height: 1.55,
  );

  static const caption = TextStyle(
    color: AppColors.textMuted,
    fontSize: 12,
    height: 1.4,
  );
}
