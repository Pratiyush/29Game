import 'dart:math';

import 'package:flutter/material.dart';

/// Palette.
class C {
  // Felt
  static const feltLight = Color(0xFF1B6B47);
  static const feltMid = Color(0xFF115339);
  static const feltDark = Color(0xFF07291C);

  // Frame / panels
  static const rail = Color(0xFF14110D);
  static const railEdge = Color(0xFF3A2A17);
  static const panel = Color(0xE60A1F16);
  static const panelSolid = Color(0xFF0C241A);
  static const ink = Color(0xFF05140E);

  // Accent
  static const gold = Color(0xFFE6B94F);
  static const goldBright = Color(0xFFF8DC97);
  static const goldDeep = Color(0xFFB98C24);

  // Text
  static const cream = Color(0xFFF4EEE2);
  static const muted = Color(0xFFA8BCAF);
  static const faint = Color(0xFF6F8579);

  // Teams
  static const us = Color(0xFF59D2C0);
  static const them = Color(0xFFFF9068);

  // Status
  static const good = Color(0xFF6BE39A);
  static const bad = Color(0xFFFF7B7B);
}

class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 999.0;
}

const _fontFamily = 'Poppins';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.feltLight,
    brightness: Brightness.dark,
    primary: C.gold,
    onPrimary: C.ink,
    surface: C.panelSolid,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: _fontFamily);
  return base.copyWith(
    scaffoldBackgroundColor: C.feltDark,
    textTheme: base.textTheme.apply(bodyColor: C.cream, displayColor: C.cream),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.gold,
        foregroundColor: C.ink,
        disabledBackgroundColor: C.faint.withValues(alpha: 0.25),
        disabledForegroundColor: C.muted,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.cream,
        side: const BorderSide(color: C.faint),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: C.gold)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.28),
      hintStyle: const TextStyle(color: C.faint),
      labelStyle: const TextStyle(color: C.muted),
      counterStyle: const TextStyle(color: C.faint, fontSize: 11),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: C.faint),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: C.faint.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: C.gold, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.panelSolid,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.panelSolid,
      contentTextStyle: const TextStyle(color: C.cream, fontFamily: _fontFamily),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    iconTheme: const IconThemeData(color: C.cream),
  );
}

Color teamColor(int seat, int mySeat) => seat % 2 == mySeat % 2 ? C.us : C.them;

/// Full-screen felt: a radial wash, a woven texture and a vignette.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.25),
              radius: 1.0,
              colors: [C.feltMid, C.feltDark, C.ink],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        const Positioned.fill(child: CustomPaint(painter: _WeavePainter())),
        child,
      ],
    );
  }
}

/// Fine cross-hatch so the felt reads as fabric rather than flat colour.
class _WeavePainter extends CustomPainter {
  const _WeavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.014)
      ..strokeWidth = 1;
    const gap = 6.0;
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
    for (var x = 0.0; x < size.width + size.height; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The oval playing surface with a bronze rail, drawn behind the seats and trick.
class TableSurface extends StatelessWidget {
  const TableSurface({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _TablePainter(), size: Size.infinite);
}

class _TablePainter extends CustomPainter {
  const _TablePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(2);
    final oval = Rect.fromCenter(center: rect.center, width: rect.width, height: min(rect.height, rect.width * 1.12));

    // Rail
    canvas.drawOval(
      oval,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.railEdge, C.rail],
        ).createShader(oval),
    );

    // Felt inside the rail
    final inner = oval.deflate(oval.width * 0.035);
    canvas.drawOval(
      inner,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          radius: 0.85,
          colors: [C.feltLight.withValues(alpha: 0.95), C.feltMid, C.feltDark.withValues(alpha: 0.85)],
          stops: const [0, 0.6, 1],
        ).createShader(inner),
    );

    // Gold hairline between rail and felt
    canvas.drawOval(
      inner.inflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = C.gold.withValues(alpha: 0.35),
    );

    // Soft centre glow where the trick lands
    canvas.drawOval(
      Rect.fromCenter(center: inner.center, width: inner.width * 0.6, height: inner.height * 0.45),
      Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0)])
            .createShader(Rect.fromCenter(center: inner.center, width: inner.width * 0.6, height: inner.height * 0.45)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Frosted panel used for the scoreboard, lobby rows and dialogs.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = AppRadius.md,
    this.color = C.panel,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

/// Wordmark used on the home screen and the lobby.
class GoldText extends StatelessWidget {
  const GoldText(this.text, {super.key, required this.size, this.letterSpacing = 0});

  final String text;
  final double size;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [C.goldBright, C.gold, C.goldDeep],
      ).createShader(bounds),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: letterSpacing,
          color: Colors.white,
        ),
      ),
    );
  }
}
