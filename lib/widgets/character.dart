import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

enum Mood { happy, neutral, sleepy }

/// An original alien form. Each one unlocks at a level.
class Alien {
  const Alien(this.id, this.name, this.level, this.color, this.blurb, this.features);
  final String id;
  final String name;
  final int level;
  final Color color;
  final String blurb;
  final Set<String> features;
}

const aliens = <Alien>[
  Alien('pip', 'Pip', 1, Color(0xFFFFB020), 'Small, stubborn, always sprouting.', {'sprouts'}),
  Alien('moji', 'Moji', 2, Color(0xFF2FD6C4), 'One big eye. Notices every skipped day.', {'tentacles', 'cyclops'}),
  Alien('bramble', 'Bramble', 4, Color(0xFF6FCF5A), 'Grows a little every single day.', {'leafEars', 'freckles'}),
  Alien('nimbo', 'Nimbo', 6, Color(0xFFC9D4FF), 'Floats on a good night of sleep.', {'cloud', 'drop'}),
  Alien('clink', 'Clink', 8, Color(0xFFC98A5A), 'Runs on routine. Never misses a cycle.', {'robot', 'bulb', 'visor'}),
  Alien('luma', 'Luma', 10, Color(0xFFA98BFF), 'Glows brighter the longer the streak.', {'bunny', 'stars', 'aura'}),
  Alien('gnash', 'Gnash', 13, Color(0xFFFF5C8A), 'Chews through excuses.', {'spikes', 'horns', 'fangs'}),
  Alien('orbis', 'Orbis', 16, Color(0xFF3B6BFF), 'A tiny planet with its own moon.', {'ring', 'moon', 'galaxy'}),
  Alien('sol', 'Sol', 20, Color(0xFFFFD34D), 'Pure discipline, burning bright.', {'rays', 'crown', 'aura'}),
];

Alien alienById(String id) => aliens.firstWhere((a) => a.id == id, orElse: () => aliens.first);
bool alienUnlocked(Alien a, int level, bool unlockAll) => unlockAll || level >= a.level;
Alien activeAlien(AppStore s, int level) {
  final a = alienById(s.settings.alien);
  return alienUnlocked(a, level, s.settings.unlockAll) ? a : aliens.first;
}

Alien? nextAlien(int level, bool unlockAll) {
  if (unlockAll) return null;
  for (final a in aliens) {
    if (a.level > level) return a;
  }
  return null;
}

Mood moodFor(AppStore s) {
  if (s.habits.isEmpty) return Mood.neutral;
  final t = todayKey();
  final done = s.habits.where((h) => s.isDone(h.id, t)).length;
  if (done == s.habits.length) return Mood.happy;
  if (done == 0 && DateTime.now().hour >= 20) return Mood.sleepy;
  return Mood.neutral;
}

/// Animated alien, drawn entirely in code.
class CharacterView extends StatefulWidget {
  const CharacterView({super.key, required this.alien, this.mood = Mood.neutral, this.size = 120, this.locked = false});
  final Alien alien;
  final Mood mood;
  final double size;
  final bool locked;

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (!widget.locked) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: AlienPainter(
            alien: widget.alien,
            mood: widget.mood,
            t: widget.locked ? 0.2 : _c.value,
            locked: widget.locked,
          ),
        ),
      ),
    );
  }
}

class AlienPainter extends CustomPainter {
  AlienPainter({required this.alien, required this.mood, required this.t, required this.locked});
  final Alien alien;
  final Mood mood;
  final double t;
  final bool locked;

  static const _tau = math.pi * 2;
  static const _ink = Color(0xFF1B1020);

  Paint _fill(Color c) => Paint()..color = c;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _oval(Canvas canvas, Offset c, double rx, double ry, Paint p, [double rot = 0]) {
    if (rot == 0) {
      canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), p);
      return;
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rot);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final f = alien.features;
    final color = alien.color;
    final light = Color.lerp(color, Colors.white, 0.5)!;
    final dark = Color.lerp(color, Colors.black, 0.38)!;
    final floats = f.contains('cloud') || f.contains('tentacles');
    final bob = math.sin(t * _tau) * w * (floats ? 0.03 : 0.018);
    final r = w * 0.2;
    final groundY = w * 0.62 + r * 1.05;
    final cx = w / 2;
    final cy = w * (floats ? 0.55 : 0.62) + bob;
    final c = Offset(cx, cy);
    final blink = (t % 0.5) > 0.475;

    if (locked) canvas.saveLayer(Offset.zero & size, Paint());

    // Shadow
    _oval(
      canvas,
      Offset(cx, groundY),
      math.max(1.0, r * (floats ? 0.55 : 0.75) - bob),
      r * 0.11,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    if (!locked && f.contains('aura')) {
      final ar = r * 2.1 * (1 + 0.06 * math.sin(t * _tau * 2));
      canvas.drawCircle(
        c,
        ar,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: ar)),
      );
    }

    // ---- back layer ----
    if (f.contains('rays')) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(t * _tau / 6);
      final p = _fill(Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: 0.85));
      for (var i = 0; i < 10; i++) {
        canvas.rotate(_tau / 10);
        final len = r * (1.55 + 0.12 * math.sin(t * _tau * 2 + i));
        canvas.drawPath(
          Path()
            ..moveTo(-r * 0.2, -r * 0.8)
            ..lineTo(0, -len)
            ..lineTo(r * 0.2, -r * 0.8)
            ..close(),
          p,
        );
      }
      canvas.restore();
    }
    if (f.contains('ring')) _ringHalf(canvas, c, r, back: true);
    if (f.contains('moon')) _moon(canvas, c, r, front: false);
    if (f.contains('sprouts')) {
      final stem = _stroke(const Color(0xFF3FA65A), r * 0.09);
      for (final s in const [-1.0, 1.0]) {
        final sway = math.sin(t * _tau * 2 + s) * r * 0.06;
        final tip = Offset(cx + s * r * 0.32 + sway, cy - r * 1.45);
        canvas.drawPath(
          Path()
            ..moveTo(cx + s * r * 0.15, cy - r * 0.9)
            ..quadraticBezierTo(cx + s * r * 0.1, cy - r * 1.25, tip.dx, tip.dy),
          stem,
        );
        _oval(canvas, tip + Offset(s * r * 0.11, -s * r * 0.08), r * 0.2, r * 0.09, _fill(const Color(0xFF5FD47A)), s * 0.7);
      }
    }
    if (f.contains('leafEars')) {
      for (final s in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + s * r * 0.92, cy - r * 0.42);
        canvas.rotate(s * -0.55 + math.sin(t * _tau) * 0.05 * s);
        _oval(canvas, Offset(s * r * 0.25, 0), r * 0.46, r * 0.19, _fill(Color.lerp(color, const Color(0xFF1F5A2A), 0.45)!));
        canvas.drawLine(Offset.zero, Offset(s * r * 0.62, 0), _stroke(Colors.white.withValues(alpha: 0.25), r * 0.03));
        canvas.restore();
      }
    }
    if (f.contains('bunny')) {
      for (final s in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(cx + s * r * 0.42, cy - r * 1.2);
        canvas.rotate(s * (0.22 + math.sin(t * _tau + s) * 0.04));
        _oval(canvas, Offset(0, -r * 0.2), r * 0.21, r * 0.62, _fill(color));
        _oval(canvas, Offset(0, -r * 0.2), r * 0.1, r * 0.45, _fill(const Color(0xFFFFC2E6).withValues(alpha: 0.8)));
        canvas.restore();
      }
    }
    if (f.contains('spikes')) {
      final p = _fill(dark);
      for (var i = 0; i < 5; i++) {
        final a = -1.1 + i * 0.55;
        final dir = Offset(math.sin(a), -math.cos(a));
        final perp = Offset(math.cos(a), math.sin(a));
        final base = c + dir * (r * 0.8);
        final len = r * (1.32 + (i == 2 ? 0.12 : 0));
        final tip = c + dir * len;
        final l = base - perp * (r * 0.2);
        final rr = base + perp * (r * 0.2);
        canvas.drawPath(
          Path()
            ..moveTo(l.dx, l.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(rr.dx, rr.dy)
            ..close(),
          p,
        );
      }
    }
    if (f.contains('tentacles')) {
      final p = _stroke(dark, r * 0.2);
      for (var i = 0; i < 4; i++) {
        final x = cx + (i - 1.5) * r * 0.42;
        final w1 = math.sin(t * _tau * 2 + i * 1.3) * r * 0.16;
        canvas.drawPath(
          Path()
            ..moveTo(x, cy + r * 0.5)
            ..quadraticBezierTo(x + w1, cy + r * 0.95, x - w1 * 0.6, cy + r * 1.3),
          p,
        );
      }
    }
    if (f.contains('drop')) {
      final dy = cy - r * 1.55 + math.sin(t * _tau * 2) * r * 0.05;
      canvas.drawLine(Offset(cx, cy - r * 0.95), Offset(cx, dy + r * 0.12), _stroke(Colors.white.withValues(alpha: 0.6), r * 0.05));
      final drop = Path()
        ..moveTo(cx, dy - r * 0.22)
        ..quadraticBezierTo(cx + r * 0.16, dy, cx + r * 0.12, dy + r * 0.08)
        ..arcToPoint(Offset(cx - r * 0.12, dy + r * 0.08), radius: Radius.circular(r * 0.12))
        ..quadraticBezierTo(cx - r * 0.16, dy, cx, dy - r * 0.22)
        ..close();
      canvas.drawPath(drop, _fill(const Color(0xFF5FB8FF)));
    }
    if (f.contains('bulb')) {
      final by = cy - r * 1.45;
      final glow = 0.5 + 0.5 * math.sin(t * _tau * 3);
      canvas.drawLine(Offset(cx, cy - r * 0.9), Offset(cx, by), _stroke(Color.lerp(color, Colors.black, 0.5)!, r * 0.06));
      canvas.drawCircle(Offset(cx, by), r * 0.22, _fill(const Color(0xFFFF5C5C).withValues(alpha: 0.25 + 0.25 * glow)));
      canvas.drawCircle(Offset(cx, by), r * 0.11, _fill(Color.lerp(const Color(0xFFFF5C5C), Colors.white, glow * 0.4)!));
    }

    // ---- body ----
    final sq = 1 - 0.03 * math.sin(t * _tau);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(1 / sq, sq);
    final shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 0.9,
      colors: [light, color, dark],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    final bodyPaint = Paint()..shader = shader;
    if (f.contains('robot')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-r * 1.02, -r * 0.92, r * 2.04, r * 1.84), Radius.circular(r * 0.42)),
        bodyPaint,
      );
    } else if (f.contains('cloud')) {
      final p = Path();
      for (final b in const [
        [0.0, 0.0, 1.0],
        [-0.72, 0.2, 0.55],
        [0.72, 0.2, 0.55],
        [-0.42, -0.55, 0.5],
        [0.42, -0.55, 0.5],
        [0.0, -0.75, 0.45],
      ]) {
        p.addOval(Rect.fromCircle(center: Offset(b[0] * r, b[1] * r), radius: b[2] * r));
      }
      canvas.drawPath(p, bodyPaint);
    } else {
      canvas.drawCircle(Offset.zero, r, bodyPaint);
    }
    if (f.contains('galaxy')) {
      for (var i = 0; i < 9; i++) {
        final a = i * 2.4;
        final d = r * (0.25 + (i % 4) * 0.17);
        final tw = 0.5 + 0.5 * math.sin(t * _tau * 2 + i);
        canvas.drawCircle(
          Offset(math.cos(a) * d, math.sin(a) * d * 0.9 + r * 0.15),
          r * 0.03,
          _fill(Colors.white.withValues(alpha: 0.35 + 0.6 * tw)),
        );
      }
    }
    canvas.restore();
    _oval(canvas, Offset(cx - r * 0.4, cy - r * 0.52), r * 0.26, r * 0.14, _fill(Colors.white.withValues(alpha: 0.25)), -0.3);

    // ---- face ----
    final ey = cy - r * 0.04;
    if (f.contains('cyclops')) {
      final er = r * 0.34;
      if (mood == Mood.happy) {
        canvas.drawPath(
          Path()
            ..moveTo(cx - er * 0.8, ey + er * 0.2)
            ..quadraticBezierTo(cx, ey - er * 1.1, cx + er * 0.8, ey + er * 0.2),
          _stroke(_ink, r * 0.09),
        );
      } else if (mood == Mood.sleepy || blink) {
        canvas.drawLine(Offset(cx - er * 0.8, ey), Offset(cx + er * 0.8, ey), _stroke(_ink, r * 0.08));
      } else {
        final look = math.sin(t * _tau) * er * 0.2;
        canvas.drawCircle(Offset(cx, ey), er, _fill(Colors.white));
        canvas.drawCircle(Offset(cx + look, ey + er * 0.08), er * 0.55, _fill(Color.lerp(color, Colors.black, 0.55)!));
        canvas.drawCircle(Offset(cx + look, ey + er * 0.08), er * 0.28, _fill(_ink));
        canvas.drawCircle(Offset(cx + look - er * 0.2, ey - er * 0.15), er * 0.14, _fill(Colors.white));
      }
    } else if (f.contains('visor')) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, ey), width: r * 1.44, height: r * 0.52),
          Radius.circular(r * 0.26),
        ),
        _fill(const Color(0xFF16161E)),
      );
      const cyan = Color(0xFF5FE3FF);
      for (final s in const [-1.0, 1.0]) {
        final ox = cx + s * r * 0.34;
        if (mood == Mood.happy) {
          canvas.drawPath(
            Path()
              ..moveTo(ox - r * 0.12, ey + r * 0.05)
              ..quadraticBezierTo(ox, ey - r * 0.14, ox + r * 0.12, ey + r * 0.05),
            _stroke(cyan, r * 0.07),
          );
        } else if (mood == Mood.sleepy || blink) {
          canvas.drawLine(Offset(ox - r * 0.12, ey), Offset(ox + r * 0.12, ey), _stroke(cyan, r * 0.07));
        } else {
          canvas.drawCircle(Offset(ox, ey), r * 0.1, _fill(cyan));
        }
      }
    } else {
      final ex = r * 0.36, er = r * 0.13;
      for (final s in const [-1.0, 1.0]) {
        final ox = cx + s * ex;
        if (mood == Mood.happy) {
          canvas.drawPath(
            Path()
              ..moveTo(ox - er, ey + er * 0.35)
              ..quadraticBezierTo(ox, ey - er * 1.3, ox + er, ey + er * 0.35),
            _stroke(_ink, r * 0.075),
          );
        } else if (mood == Mood.sleepy || blink) {
          canvas.drawLine(Offset(ox - er * 0.9, ey), Offset(ox + er * 0.9, ey), _stroke(_ink, r * 0.075));
        } else {
          _oval(canvas, Offset(ox, ey), er * 0.8, er * 1.05, _fill(_ink));
          canvas.drawCircle(Offset(ox - er * 0.25, ey - er * 0.42), er * 0.33, _fill(Colors.white));
        }
      }
    }
    if (!f.contains('visor')) {
      for (final s in const [-1.0, 1.0]) {
        _oval(canvas, Offset(cx + s * r * 0.62, ey + r * 0.32), r * 0.15, r * 0.085, _fill(const Color(0xFFFF6B9A).withValues(alpha: 0.45)));
      }
    }
    if (f.contains('freckles')) {
      final p = _fill(const Color(0xFF1F5A2A).withValues(alpha: 0.55));
      for (final s in const [-1.0, 1.0]) {
        for (final d in const [
          [0.55, 0.2],
          [0.68, 0.28],
          [0.58, 0.36],
        ]) {
          canvas.drawCircle(Offset(cx + s * r * d[0], ey + r * d[1]), r * 0.03, p);
        }
      }
    }
    final my = cy + r * (f.contains('cyclops') ? 0.45 : 0.32);
    final mouthColor = f.contains('visor') ? Color.lerp(color, Colors.black, 0.55)! : _ink;
    if (mood == Mood.sleepy) {
      canvas.drawCircle(Offset(cx, my + r * 0.03), r * 0.06, _fill(mouthColor));
    } else {
      final mw = mood == Mood.happy ? r * 0.24 : r * 0.14;
      final dp = mood == Mood.happy ? r * 0.24 : r * 0.1;
      canvas.drawPath(
        Path()
          ..moveTo(cx - mw, my)
          ..quadraticBezierTo(cx, my + dp, cx + mw, my),
        _stroke(mouthColor, r * 0.065),
      );
      if (f.contains('fangs')) {
        for (final s in const [-1.0, 1.0]) {
          final fx = cx + s * mw * 0.55, fy = my + dp * 0.3;
          canvas.drawPath(
            Path()
              ..moveTo(fx - r * 0.05, fy)
              ..lineTo(fx, fy + r * 0.12)
              ..lineTo(fx + r * 0.05, fy)
              ..close(),
            _fill(Colors.white),
          );
        }
      }
    }

    // ---- front layer ----
    if (f.contains('horns')) {
      for (final s in const [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(cx + s * r * 0.3, cy - r * 0.88)
            ..quadraticBezierTo(cx + s * r * 0.45, cy - r * 1.3, cx + s * r * 0.62, cy - r * 1.32)
            ..quadraticBezierTo(cx + s * r * 0.5, cy - r * 1.05, cx + s * r * 0.55, cy - r * 0.78)
            ..close(),
          _fill(const Color(0xFFFFF3E3)),
        );
      }
    }
    if (f.contains('crown')) {
      final y = cy - r * 0.9;
      canvas.drawPath(
        Path()
          ..moveTo(cx - r * 0.42, y)
          ..lineTo(cx - r * 0.48, y - r * 0.42)
          ..lineTo(cx - r * 0.2, y - r * 0.2)
          ..lineTo(cx, y - r * 0.5)
          ..lineTo(cx + r * 0.2, y - r * 0.2)
          ..lineTo(cx + r * 0.48, y - r * 0.42)
          ..lineTo(cx + r * 0.42, y)
          ..close(),
        _fill(const Color(0xFFFFF1A8)),
      );
    }
    if (f.contains('ring')) _ringHalf(canvas, c, r, back: false);
    if (f.contains('moon')) _moon(canvas, c, r, front: true);
    if (f.contains('stars')) {
      final p = _fill(const Color(0xFFFFF6C9));
      for (final st in const [
        [-1.45, -0.9, 0.0],
        [1.5, -0.5, 1.7],
        [1.2, 0.75, 3.1],
      ]) {
        final s2 = r * 0.13 * (0.55 + 0.45 * math.sin(t * _tau * 2 + st[2]));
        final x = cx + st[0] * r, y = cy + st[1] * r;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - s2 * 2)
            ..quadraticBezierTo(x, y, x + s2 * 2, y)
            ..quadraticBezierTo(x, y, x, y + s2 * 2)
            ..quadraticBezierTo(x, y, x - s2 * 2, y)
            ..quadraticBezierTo(x, y, x, y - s2 * 2)
            ..close(),
          p,
        );
      }
    }

    if (locked) {
      canvas.drawRect(Offset.zero & size, Paint()
        ..color = const Color(0xFF26262F)
        ..blendMode = BlendMode.srcATop);
      canvas.restore();
    }
  }

  void _ringHalf(Canvas canvas, Offset c, double r, {required bool back}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.3);
    final rect = Rect.fromCenter(center: Offset.zero, width: r * 3.3, height: r * 0.84);
    canvas.drawArc(rect, back ? math.pi : 0, math.pi, false,
        _stroke(const Color(0xFF9FD0FF).withValues(alpha: back ? 0.85 : 0.95), r * 0.14));
    canvas.restore();
  }

  void _moon(Canvas canvas, Offset c, double r, {required bool front}) {
    final a = t * _tau;
    if ((math.sin(a) > 0) != front) return;
    final m = Offset(c.dx + math.cos(a) * r * 1.6, c.dy + math.sin(a) * r * 0.42 - math.cos(a) * r * 0.45);
    canvas.drawCircle(m, r * 0.17, _fill(const Color(0xFFD7DBE8)));
    canvas.drawCircle(m + Offset(r * 0.05, r * 0.04), r * 0.05, _fill(Colors.black.withValues(alpha: 0.18)));
  }

  @override
  bool shouldRepaint(AlienPainter old) =>
      old.t != t || old.alien.id != alien.id || old.mood != mood || old.locked != locked;
}
