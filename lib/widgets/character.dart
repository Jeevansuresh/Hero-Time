import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models.dart';
import '../store.dart';

enum Mood { happy, neutral, sleepy }

/// One DNA sample in the watch. Each unlocks at a level.
/// Built-in art is loaded from assets/aliens/<id>.png. Custom heroes (added on the
/// phone) carry their photo bytes instead; those live only on the device.
class Alien {
  const Alien(this.id, this.name, this.species, this.level, this.color, this.blurb, {this.photo});
  final String id;
  final String name;
  final String species;
  final int level;
  final Color color;
  final String blurb;

  /// Photo of a custom hero (PNG/JPEG bytes). Null for built-in aliens.
  final Uint8List? photo;

  bool get custom => id.startsWith(customHeroPrefix);
  String get asset => 'assets/aliens/$id.png';
  ImageProvider get image => photo != null ? MemoryImage(photo!) : AssetImage(asset);
  String get initials {
    final words = name.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').split(' ').where((w) => w.isNotEmpty);
    return words.isEmpty ? '?' : words.map((w) => w[0].toUpperCase()).take(2).join();
  }

  Alien copyWith({String? name, String? species, Color? color, String? blurb, Uint8List? photo}) => Alien(
        id, name ?? this.name, species ?? this.species, level, color ?? this.color, blurb ?? this.blurb,
        photo: photo ?? this.photo,
      );

  /// Custom-hero details for storage (the photo is stored separately).
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'species': species, 'color': color.toARGB32(), 'blurb': blurb};
  static Alien fromJson(Map<String, dynamic> j, Uint8List? photo) => Alien(
        j['id'] as String,
        (j['name'] ?? 'Hero') as String,
        (j['species'] ?? 'Human') as String,
        1,
        Color((j['color'] ?? 0xFFC0D72D) as int),
        (j['blurb'] ?? '') as String,
        photo: photo,
      );

  static Uint8List? decodePhoto(String? b64) => b64 == null ? null : base64Decode(b64);

  @override
  bool operator ==(Object other) => other is Alien && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

const customHeroPrefix = 'hero_';

/// Every form in the watch: the built-in aliens, then your own heroes (always unlocked).
/// The store refreshes this when heroes are added, edited or removed.
List<Alien> aliens = [...builtInAliens];
List<Alien> get customHeroes => aliens.where((a) => a.custom).toList();
void setCustomHeroes(List<Alien> heroes) => aliens = [...builtInAliens, ...heroes];

const builtInAliens = <Alien>[
  Alien('heatblast', 'Heatblast', 'Pyronite', 1, Color(0xFFFF7A1A), 'Turns up the heat on every habit.'),
  Alien('diamondhead', 'Diamondhead', 'Petrosapien', 2, Color(0xFF6FE3A8), 'Routines as hard as crystal.'),
  Alien('xlr8', 'XLR8', 'Kineceleran', 4, Color(0xFF3FB4FF), 'Fastest check-in in the galaxy.'),
  Alien('fourarms', 'Four Arms', 'Tetramand', 6, Color(0xFFFF3B3B), 'Four arms, four gym days.'),
  Alien('cannonbolt', 'Cannonbolt', 'Arburian Pelarota', 8, Color(0xFFFFC21A), 'Rolls right through excuses.'),
  Alien('swampfire', 'Swampfire', 'Methanosian', 10, Color(0xFF8BC34A), 'Grows back stronger after a slip.'),
  Alien('jetray', 'Jetray', 'Aerophibian', 12, Color(0xFFE0313F), 'Flies over every craving.'),
  Alien('bigchill', 'Big Chill', 'Necrofriggian', 14, Color(0xFF4A8BFF), 'Ice cold under pressure.'),
  Alien('humungousaur', 'Humungousaur', 'Vaxasaurian', 16, Color(0xFFD4A65A), 'Grows bigger with every rep.'),
  Alien('waybig', 'Way Big', "To'kustar", 18, Color(0xFFE8E8EE), 'Discipline on a cosmic scale.'),
  Alien('alienx', 'Alien X', 'Celestialsapien', 20, Color(0xFFC0D72D), 'Infinite power. Total consistency.'),
];

Alien alienById(String id) => aliens.firstWhere((a) => a.id == id, orElse: () => aliens.first);
bool alienUnlocked(Alien a, int level, bool unlockAll) => unlockAll || level >= a.level;
Alien activeAlien(AppStore s, int level) {
  final a = alienById(s.settings.alien);
  return alienUnlocked(a, level, s.settings.unlockAll) ? a : aliens.first;
}

Alien? nextAlien(int level, bool unlockAll) {
  if (unlockAll) return null;
  for (final a in builtInAliens) {
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

/// The active alien: floats gently over a glow in its own colour.
/// Locked aliens render as a dark silhouette, like an unscanned DNA sample.
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
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (widget.locked && _c.isAnimating) _c.stop();
    if (!widget.locked && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alien;
    final size = widget.size;
    final fallback = _Hologram(alien: a, locked: widget.locked);
    Widget art = Image(
      image: a.image,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
    if (widget.locked) {
      art = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF0A110C), BlendMode.srcIn),
        child: art,
      );
    } else if (widget.mood == Mood.sleepy) {
      art = Opacity(opacity: 0.55, child: art);
    }

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = widget.locked ? 0.0 : _c.value;
          final bob = math.sin(t * math.pi * 2) * size * 0.025;
          final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2);
          final glow = widget.locked
              ? 0.0
              : (widget.mood == Mood.happy ? 0.45 : (widget.mood == Mood.sleepy ? 0.12 : 0.28)) + 0.08 * pulse;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (glow > 0)
                Container(
                  width: size * 0.7,
                  height: size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: a.color.withValues(alpha: glow), blurRadius: size * 0.35, spreadRadius: size * 0.02)],
                  ),
                ),
              // Floor shadow
              Positioned(
                bottom: size * 0.04,
                child: Container(
                  width: size * (0.42 - 0.04 * (bob / (size * 0.025)).abs()),
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    color: Colors.black.withValues(alpha: 0.45),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: size * 0.04)],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, bob - size * 0.02),
                child: Padding(padding: EdgeInsets.all(size * 0.03), child: child),
              ),
            ],
          );
        },
        child: art,
      ),
    );
  }
}

/// Stand-in until the alien's art is added: a DNA hologram in the alien's colour.
class _Hologram extends StatelessWidget {
  const _Hologram({required this.alien, required this.locked});
  final Alien alien;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final s = c.biggest.shortestSide;
      final col = locked ? const Color(0xFF2A3A2E) : alien.color;
      return Center(
        child: SizedBox(
          width: s,
          height: s,
          child: CustomPaint(
            painter: _HoloPainter(col),
            child: Center(
              child: Text(
                locked ? '?' : alien.initials,
                style: GoogleFonts.orbitron(
                  fontSize: s * 0.24,
                  fontWeight: FontWeight.w800,
                  color: locked ? const Color(0xFF3E5443) : Colors.white,
                  shadows: locked ? null : [Shadow(color: col, blurRadius: s * 0.08)],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _HoloPainter extends CustomPainter {
  _HoloPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(
      c,
      r * 0.92,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.04)])
            .createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04
      ..color = color.withValues(alpha: 0.85);
    // Segmented outer ring, like a watch bezel.
    for (var i = 0; i < 8; i++) {
      final start = i * math.pi / 4 + 0.08;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.9), start, math.pi / 4 - 0.16, false, ring);
    }
    // Hourglass ghost behind the initials.
    final w = r * 0.5, h = r * 0.55, waist = r * 0.08;
    final p = Path()
      ..moveTo(c.dx - w, c.dy - h)
      ..lineTo(c.dx + w, c.dy - h)
      ..lineTo(c.dx + waist, c.dy)
      ..lineTo(c.dx + w, c.dy + h)
      ..lineTo(c.dx - w, c.dy + h)
      ..lineTo(c.dx - waist, c.dy)
      ..close();
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: 0.16));
  }

  @override
  bool shouldRepaint(_HoloPainter old) => old.color != color;
}
