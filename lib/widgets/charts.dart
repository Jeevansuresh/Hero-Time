import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Progress ring (0..1).
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 88, this.stroke = 9, this.color = AppColors.green, this.child});
  final double value, size, stroke;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, color), child: Center(child: child)),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color);
  final double v, stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (v <= 0) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v, false, p);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color;
}

/// Smooth line with a soft fill underneath (values 0..1, oldest → newest).
class AreaChart extends StatelessWidget {
  const AreaChart({super.key, required this.values, required this.color, this.height = 110, this.labels = true});
  final List<double> values;
  final Color color;
  final double height;
  final bool labels;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _AreaPainter(values, color))),
          if (labels) ...[
            const SizedBox(height: 6),
            Row(children: [
              Text('${values.length - 1} wks ago', style: ui(10, color: AppColors.faint)),
              const Spacer(),
              Text('This week', style: ui(10, color: AppColors.faint)),
            ]),
          ],
        ],
      );
}

Path _smooth(List<Offset> p) {
  final path = Path()..moveTo(p[0].dx, p[0].dy);
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = i > 0 ? p[i - 1] : p[i], p1 = p[i], p2 = p[i + 1], p3 = i + 2 < p.length ? p[i + 2] : p2;
    path.cubicTo(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6, p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6, p2.dx, p2.dy);
  }
  return path;
}

class _AreaPainter extends CustomPainter {
  _AreaPainter(this.v, this.color);
  final List<double> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    if (v.length < 2) return;
    final grid = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (final g in [0.0, .5, 1.0]) {
      final y = 6 + (1 - g) * (s.height - 12);
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
    final pts = [
      for (var i = 0; i < v.length; i++) Offset(4 + i * (s.width - 8) / (v.length - 1), 6 + (1 - v[i].clamp(0, 1)) * (s.height - 12))
    ];
    final line = _smooth(pts);
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, s.height)
      ..lineTo(pts.first.dx, s.height)
      ..close();
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & s));
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = color);
    canvas.drawCircle(pts.last, 5, Paint()..color = color);
    canvas.drawCircle(pts.last, 5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.card);
  }

  @override
  bool shouldRepaint(_AreaPainter o) => o.v != v || o.color != color;
}

/// Tiny trend line for list rows.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.width = 60, this.height = 24});
  final List<double> values;
  final Color color;
  final double width, height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width, height: height, child: CustomPaint(painter: _SparkPainter(values, color)));
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color);
  final List<double> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    if (v.length < 2) return;
    final pts = [
      for (var i = 0; i < v.length; i++) Offset(2 + i * (s.width - 4) / (v.length - 1), 3 + (1 - v[i].clamp(0, 1)) * (s.height - 6))
    ];
    canvas.drawPath(
        _smooth(pts),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.v != v || o.color != color;
}
