import 'package:flutter/material.dart';

// Display tokens. Device terminals can override the phosphor without changing
// permission, telemetry or control state.
abstract final class SamTokens {
  static const bg = Color(0xff050708);
  static const panel = Color(0xff0b0e0f);
  static const phosphor = Color(0xffb6d5d0);
  static const text = Color(0xffd8e2df);
  static const dim = Color(0xff748984);
  static const line = Color(0xff283b37);
  static const amber = Color(0xffd8ab71);
  static const blue = Color(0xff89b9cf);
  static const critical = Color(0xffd87872);
  static const hairline = .6;
  static const scanlineOpacity = .055;
  static const noiseOpacity = .035;
  static const glowStrength = .08;
}

const background = Color(0xff050708);
const surface = Color(0xff0b0e0f);
const ink = Color(0xffd8e2df);
const muted = Color(0xff8a9c97);
const accent = SamTokens.phosphor;
const line = Color(0xff283b37);
const warning = Color(0xffd6b96d);
const critical = Color(0xffd87872);

Color statusColor(String status) => switch (status) {
  'ONLINE' || 'NORMAL' || 'ESTABLISHED' || 'SUCCEEDED' || 'RESOLVED' => accent,
  'WARNING' || 'DEGRADED' || 'ACKNOWLEDGED' => warning,
  'CRITICAL' || 'FAILED' => critical,
  _ => muted,
};

ThemeData samTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: background,
  colorScheme: const ColorScheme.dark(
    primary: accent,
    surface: surface,
    error: critical,
  ),
  fontFamily: 'RobotoMono',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: ink, fontSize: 12, height: 1.45),
    titleLarge: TextStyle(
      fontFamily: 'RobotoCondensed',
      color: ink,
      fontSize: 18,
      letterSpacing: 2.4,
      fontWeight: FontWeight.w600,
    ),
  ),
  dividerColor: line,
  dividerTheme: const DividerThemeData(color: line, thickness: 1),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: surface,
    contentTextStyle: TextStyle(color: ink, fontFamily: 'RobotoMono'),
    shape: RoundedRectangleBorder(side: BorderSide(color: line)),
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    labelStyle: const TextStyle(color: muted, fontSize: 10, letterSpacing: 1),
    border: const UnderlineInputBorder(borderSide: BorderSide(color: line)),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: line),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: accent),
    ),
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: accent,
      minimumSize: const Size(44, 44),
      shape: const RoundedRectangleBorder(),
      textStyle: const TextStyle(
        fontFamily: 'RobotoCondensed',
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: const BorderSide(color: Colors.transparent),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      minimumSize: const Size(44, 44),
      textStyle: const TextStyle(
        fontFamily: 'RobotoCondensed',
        fontSize: 12,
        letterSpacing: 1.1,
      ),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: surface,
    shape: RoundedRectangleBorder(),
  ),
);
