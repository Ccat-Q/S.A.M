import 'package:flutter/material.dart';

const background = Color(0xff050708);
const surface = Color(0xff0b0e0f);
const ink = Color(0xffd8e2df);
const muted = Color(0xff8a9c97);
const accent = Color(0xff8fc9bc);
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
    bodyMedium: TextStyle(color: ink, fontSize: 13, height: 1.5),
    titleLarge: TextStyle(
      fontFamily: 'RobotoCondensed',
      color: ink,
      fontSize: 23,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
    ),
  ),
  dividerColor: line,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surface,
    border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: line),
      borderRadius: BorderRadius.zero,
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: accent),
      borderRadius: BorderRadius.zero,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: accent,
      side: const BorderSide(color: line),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      minimumSize: const Size(44, 44),
      textStyle: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: surface,
    shape: RoundedRectangleBorder(),
  ),
);
