import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

enum AppThemeMode { light, dark, banking }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _currentThemeMode = AppThemeMode.light;

  AppThemeMode get currentThemeMode => _currentThemeMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // جلب الثيم المحفوظ مسبقاً
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('app_theme_mode') ?? 0;
    _currentThemeMode = AppThemeMode.values[themeIndex];
    notifyListeners();
  }

  // تغيير وحفظ الثيم
  Future<void> setThemeMode(AppThemeMode mode) async {
    _currentThemeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_theme_mode', mode.index);
    notifyListeners();
  }

  // بناء الـ ThemeData الخاص بـ Flutter بناءً على الوضع الحالي
  ThemeData get getThemeData {
    switch (_currentThemeMode) {
      case AppThemeMode.dark:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.darkBackground,
          primaryColor: AppColors.darkPrimary,
          cardColor: AppColors.darkSurface,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.darkPrimary,
            surface: AppColors.darkSurface,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
            bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
          ),
        );

      case AppThemeMode.banking:
        return ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bankingBackground,
          primaryColor: AppColors.bankingPrimary,
          cardColor: AppColors.bankingSurface,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.bankingPrimary,
            surface: AppColors.bankingSurface,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.bankingTextPrimary),
            bodyMedium: TextStyle(color: AppColors.bankingTextSecondary),
          ),
        );

      case AppThemeMode.light:
      return ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.lightBackground,
          primaryColor: AppColors.lightPrimary,
          cardColor: AppColors.lightSurface,
          colorScheme: const ColorScheme.light(
            primary: AppColors.lightPrimary,
            surface: AppColors.lightSurface,
          ),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
            bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
          ),
        );
    }
  }
}