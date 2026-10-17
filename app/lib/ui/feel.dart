/// Game feel: sound effects, haptics, announcement banners and confetti.
/// Every leading 29 app has these; without them a won contract feels like a spreadsheet update.
library;

import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../prefs.dart';
import 'theme.dart';

/// Short card-table sounds (Kenney Casino Audio, CC0) in assets/sfx.
class Sfx {
  Sfx._();

  /// Tests and headless runs switch this off; there is no audio plugin there.
  static bool enabled = true;

  static final List<AudioPlayer> _pool = [];
  static int _next = 0;
  static final _random = Random();

  static bool get _on {
    if (!enabled) return false;
    try {
      return Prefs.instance.sound;
    } catch (_) {
      return false;
    }
  }

  static void deal() => _play('deal');
  static void playCard() => _play('play${1 + _random.nextInt(3)}');
  static void trick() => _play('trick');
  static void turn() => _play('turn');
  static void bid() => _play('bid');
  static void win() => _play('win');
  static void lose() => _play('lose');
  static void reveal() => _play('reveal');
  static void pair() => _play('pair');

  static void _play(String name) {
    if (!_on) return;
    try {
      if (_pool.length < 4) {
        _pool.add(AudioPlayer()..setPlayerMode(PlayerMode.lowLatency));
      }
      final p = _pool[_next++ % _pool.length];
      p.stop().then((_) => p.play(AssetSource('sfx/$name.mp3'), volume: 0.8)).catchError((Object _) {});
    } catch (_) {
      // Audio is a nicety; never let it break the game.
    }
  }
}

class Haptics {
  Haptics._();

  static bool get _on {
    try {
      return Prefs.instance.haptics;
    } catch (_) {
      return false;
    }
  }

  static void tap() {
    if (_on) HapticFeedback.selectionClick();
  }

  static void play() {
    if (_on) HapticFeedback.lightImpact();
  }

  static void big() {
    if (_on) HapticFeedback.mediumImpact();
  }
}

/// A banner that drops in at the top of the table: "Trump revealed", "Pair!", ...
class Announcement {
  const Announcement(this.title, this.detail, {this.icon, this.color = C.gold});

  final String title;
  final String detail;
  final Widget? icon;
  final Color color;
}

class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key, required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    final a = announcement;
    return TweenAnimationBuilder<double>(
      key: ValueKey(a),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -24 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 20, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [C.panelSolid, Color.lerp(C.panelSolid, a.color, 0.18)!]),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: a.color.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [BoxShadow(color: a.color.withValues(alpha: 0.35), blurRadius: 18)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a.icon != null) ...[a.icon!, const SizedBox(width: 10)],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  style: TextStyle(color: a.color, fontWeight: FontWeight.w800, fontSize: 15, height: 1.1),
                ),
                if (a.detail.isNotEmpty)
                  Text(a.detail, style: const TextStyle(color: C.cream, fontSize: 12, height: 1.3)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Falling confetti, played once. [big] for a match win.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.big = false});

  final bool big;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.big ? 3200 : 2000),
  )..forward();

  late final List<_Bit> _bits = _makeBits(widget.big ? 150 : 80);

  static const _colors = [C.gold, C.goldBright, C.us, C.them, C.cream, Color(0xFFE85D75)];

  List<_Bit> _makeBits(int n) {
    final r = Random();
    return List.generate(
      n,
      (_) => _Bit(
        x: r.nextDouble(),
        delay: r.nextDouble() * 0.35,
        speed: 0.55 + r.nextDouble() * 0.6,
        drift: (r.nextDouble() - 0.5) * 0.25,
        spin: (r.nextDouble() - 0.5) * 18,
        size: 5 + r.nextDouble() * 6,
        color: _colors[r.nextInt(_colors.length)],
        round: r.nextBool(),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_bits, _c.value), size: Size.infinite),
      ),
    );
  }
}

class _Bit {
  _Bit({
    required this.x,
    required this.delay,
    required this.speed,
    required this.drift,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double x, delay, speed, drift, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);

  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in bits) {
      final local = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * b.speed * (size.height + 60);
      final x = (b.x + b.drift * local + sin(local * 9 + b.x * 20) * 0.015) * size.width;
      final fade = local > 0.8 ? (1 - local) / 0.2 : 1.0;
      paint.color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * local);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size * 0.45, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * 0.45), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
