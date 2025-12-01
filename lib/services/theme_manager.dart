import 'package:flutter/material.dart';

enum AppThemeMode {
  light,
  dark,
  inverse,
  blueprint,
}

class ThemeManager with ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.light;

  AppThemeMode get currentTheme => _currentTheme;

  void setTheme(AppThemeMode theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  ThemeData getThemeData() {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return _lightTheme();
      case AppThemeMode.dark:
        return _darkTheme();
      case AppThemeMode.inverse:
        return _inverseTheme();
      case AppThemeMode.blueprint:
        return _blueprintTheme();
    }
  }

  ThemeData _lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: Colors.blue,
        secondary: Colors.blueAccent,
        surface: Colors.white,
        background: Colors.grey[50]!,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  ThemeData _darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[300]!,
        secondary: Colors.blueAccent[100]!,
        surface: Colors.grey[850]!,
        background: Colors.grey[900]!,
      ),
      scaffoldBackgroundColor: Colors.grey[900],
      cardTheme: CardThemeData(
        color: Colors.grey[850],
        elevation: 2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  ThemeData _inverseTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Colors.grey[800]!,
        onSecondary: Colors.white,
        error: Colors.red,
        onError: Colors.white,
        background: Colors.white,
        onBackground: Colors.black,
        surface: Colors.grey[100]!,
        onSurface: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.white,
      cardTheme: CardThemeData(
        color: Colors.grey[100],
        elevation: 2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }

  ThemeData _blueprintTheme() {
    const blueprintBlue = Color(0xFF0D47A1);
    const blueprintBackground = Color(0xFF1A237E);
    const blueprintPaper = Color(0xFF283593);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: Colors.cyan[300]!,
        onPrimary: blueprintBackground,
        secondary: Colors.lightBlue[200]!,
        onSecondary: blueprintBackground,
        error: Colors.red[300]!,
        onError: blueprintBackground,
        background: blueprintBackground,
        onBackground: Colors.cyan[100]!,
        surface: blueprintPaper,
        onSurface: Colors.cyan[100]!,
      ),
      scaffoldBackgroundColor: blueprintBackground,
      cardTheme: CardThemeData(
        color: blueprintPaper,
        elevation: 2,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: blueprintBlue,
        foregroundColor: Colors.cyan[100],
        elevation: 2,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: Colors.cyan[100]),
        bodyMedium: TextStyle(color: Colors.cyan[100]),
        bodySmall: TextStyle(color: Colors.cyan[200]),
      ),
    );
  }

  Color getGridColor() {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return Colors.blue.withOpacity(0.15);
      case AppThemeMode.dark:
        return Colors.cyan.withOpacity(0.25);
      case AppThemeMode.inverse:
        return Colors.grey.withOpacity(0.3);
      case AppThemeMode.blueprint:
        return Colors.cyan.withOpacity(0.4);
    }
  }

  Color getGridLabelColor() {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return Colors.blue.withOpacity(0.6);
      case AppThemeMode.dark:
        return Colors.cyan.withOpacity(0.8);
      case AppThemeMode.inverse:
        return Colors.grey[700]!;
      case AppThemeMode.blueprint:
        return Colors.cyan[100]!;
    }
  }

  Color getViewportBackground() {
    switch (_currentTheme) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.dark:
        return Colors.grey[850]!;
      case AppThemeMode.inverse:
        return Colors.white;
      case AppThemeMode.blueprint:
        return Color(0xFF1A237E);
    }
  }
}
