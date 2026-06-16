import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF00B074);
  static const Color primaryDark = Color(0xFF008F5D);
  static const Color backgroundTeal = Color(0xFFB2DFDB);
  static const Color white = Colors.white;

  static const Color primaryBlue = primary;
  static const Color accentBlue = primaryDark;

  static ThemeData lightTheme = ThemeData(
    primaryColor: primary,
    scaffoldBackgroundColor: white,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
    ),
  );

  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
