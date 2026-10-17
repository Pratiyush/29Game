import 'package:flutter/material.dart';

class AppColors {
  static const feltCenter = Color(0xFF1F7A4D);
  static const feltEdge = Color(0xFF0B3D26);
  static const gold = Color(0xFFF2C14E);
  static const usTeam = Color(0xFF4FC3F7);
  static const themTeam = Color(0xFFFF8A65);
  static const panel = Color(0xCC0A2A1B);
  static const ink = Color(0xFF10261A);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.feltCenter,
    brightness: Brightness.dark,
    primary: AppColors.gold,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.feltEdge,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.ink,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
  );
}

/// Green felt background used behind every screen.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(colors: [AppColors.feltCenter, AppColors.feltEdge], radius: 1.1),
      ),
      child: child,
    );
  }
}

Color teamColor(int seat, int mySeat) => seat % 2 == mySeat % 2 ? AppColors.usTeam : AppColors.themTeam;
