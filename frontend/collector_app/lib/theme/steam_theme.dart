import 'package:flutter/material.dart';

class SteamColors {
  static const bg = Color(0xFF171A21);
  static const panel = Color(0xFF1B2838);
  static const panel2 = Color(0xFF2A475E);
  static const accent = Color(0xFF66C0F4);
  static const text = Color(0xFFC7D5E0);
  static const textMuted = Color(0xFF8F98A0);
}

ThemeData steamTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SteamColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: SteamColors.accent,
      surface: SteamColors.panel,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: SteamColors.bg,
      foregroundColor: SteamColors.text,
      elevation: 0,
    ),
  );
}
