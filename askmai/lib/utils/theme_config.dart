import 'package:flutter/material.dart';

/// 应用主题配置 - 支持浅色和深色主题
class AppThemeConfig {
  // 浅色主题颜色 - 黑白灰浅色系
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF5B77D2);
  static const Color lightPrimaryLight = Color(0xFF7A92E8);
  static const Color lightText = Color(0xFF2D2D2D);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightBorder = Color(0xFFD0D0D0);

  // 深色主题颜色
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF7A92E8);
  static const Color darkPrimaryLight = Color(0xFF9AB0FF);
  static const Color darkText = Color(0xFFEEEEEE);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkDivider = Color(0xFF2C2C2C);
  static const Color darkBorder = Color(0xFF333333);

  // UI与WebView之间的软隔离阴影
  static const double shadowBlur = 5.0;
  static const double shadowOffsetY = -3.0;

  // 右键菜单阴影
  static List<BoxShadow> menuShadow(bool isDark) => [
    BoxShadow(
      color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
      blurRadius: shadowBlur,
      offset: Offset(0, shadowBlur / 2),
    ),
  ];

  static List<BoxShadow> get lightMenuShadow => menuShadow(false);
  static List<BoxShadow> get darkMenuShadow => menuShadow(true);

  /// 构建浅色主题
  static ThemeData buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 1,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightText),
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        onPrimary: Colors.white,
        secondary: lightPrimaryLight,
        onSecondary: Colors.white,
        surface: lightSurface,
        onSurface: lightText,
      ),
      // 文本主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: lightText, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        bodySmall: TextStyle(color: lightTextSecondary),
        labelLarge: TextStyle(color: lightText, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: lightText, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: lightTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: lightText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightText.withValues(alpha: 0.9),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return lightPrimary;
          }
          return lightTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return lightPrimary.withValues(alpha: 0.3);
          }
          return lightDivider;
        }),
      ), dialogTheme: const DialogThemeData(backgroundColor: lightSurface),
    );
  }

  /// 构建深色主题
  static ThemeData buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 1,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: darkBackground,
        secondary: darkPrimaryLight,
        onSecondary: darkBackground,
        surface: darkSurface,
        onSurface: darkText,
      ),
      // 文本主题
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
        bodySmall: TextStyle(color: darkTextSecondary),
        labelLarge: TextStyle(color: darkText, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: darkText, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: darkTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: darkText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBackground,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkBorder, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkText.withValues(alpha: 0.9),
        contentTextStyle: const TextStyle(color: darkBackground),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary;
          }
          return darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary.withValues(alpha: 0.3);
          }
          return darkBorder;
        }),
      ), dialogTheme: const DialogThemeData(backgroundColor: darkSurface),
    );
  }
}
