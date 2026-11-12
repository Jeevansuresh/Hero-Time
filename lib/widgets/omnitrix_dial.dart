import 'dart:math' as math;
import 'dart:ui' as dui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../sfx.dart';
import '../theme.dart';
import 'character.dart';

double get _step => 360 / aliens.length;
double _rad(double deg) => deg * math.pi / 180;

/// The interactive Omnitrix.
///
/// Idle: the current form stands above a closed watch. Tap the watch to activate it:
/// the hourglass pops up and a DNA ring of every alien fans out around the dial. Turn
/// the dial to browse (unlocked aliens project as a hologram, locked ones as a mystery
/// silhouette), then slam the hourglass to transform.
class OmnitrixDial extends StatefulWidget {
  const OmnitrixDial({
    super.key,
    required this.current,
    required this.mood,
    required this.level,
    required this.unlockAll,
    required this.height,
    required this.onTransform,
  });

  final Alien current;
  final Mood mood;
  final int level;
  final bool unlockAll;

  /// Height the whole section may use (the visible area below the app bar).
  final double height;
  final ValueChanged<Alien> onTransform;

  @override
  State<OmnitrixDial> createState() => _OmnitrixDialState();
}

class _OmnitrixDialState extends State<OmnitrixDial> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  late final AnimationController _snap = AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _slam = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  double _rot = 0;
  int _sel = 0;
  bool _isOpen = false;
  double _snapFrom = 0, _snapTo = 0;

  // Drag state
  double _lastAngle = 0, _moved = 0;
  bool _downOnFace = false;
  double _wrap = 304;

  @override
  void initState() {
    super.initState();
    _sel = aliens.indexOf(widget.current);
    _rot = -_sel * _step;
    _snap.addListener(() {
      final t = Curves.easeOutCubic.transform(_snap.value);
      _setRot(dui.lerpDouble(_snapFrom, _snapTo, t)!);
    });
  }

  @override
  void didUpdateWidget(OmnitrixDial old) {
    super.didUpdateWidget(old);
    if (!_isOpen && old.current.id != widget.current.id) {
      _sel = aliens.indexOf(widget.current);
    }
  }

  @override
  void dispose() {
    for (final c in [_open, _pulse, _snap, _flash, _slam, _shake]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _unlocked(Alien a) => alienUnlocked(a, widget.level, widget.unlockAll);
  int _indexAt(double r) {
    final n = aliens.length;
    return ((-r / _step).round() % n + n) % n;
  }

  void _setRot(double r) {
    final i = _indexAt(r);
    final changed = i != _sel;
    setState(() {
      _rot = r;
      _sel = i;
    });
    if (changed && _isOpen) {
      HapticFeedback.selectionClick();
      Sfx.play('dial');
    }
  }

  void _animateTo(double target) {
    _snapFrom = _rot;
    _snapTo = target;
    _snap.forward(from: 0);
  }

  void _turn(int dir) {
    if (!_isOpen) return;
    _animateTo((_rot / _step).round() * _step - dir * _step);
  }

  void _activate() {
    if (_isOpen) return;
    final i = aliens.indexOf(widget.current);
    final base = (_rot / 360).round() * 360.0;
    setState(() {
      _isOpen = true;
      _sel = i;
      _rot = base - i * _step;
    });
    _open.forward();
    Sfx.play('initiate');
    HapticFeedback.mediumImpact();
  }

  void _close() {
    setState(() => _isOpen = false);
    _open.reverse();
  }

  void _transform() {
    final a = aliens[_sel];
    if (!_unlocked(a)) {
      Sfx.play('denied');
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      return;
    }
    if (a.id == widget.current.id) {
      Sfx.play('undo');
      _close();
      return;
    }
    Sfx.play('transform');
    HapticFeedback.heavyImpact();
    _slam.forward(from: 0);
    _flash.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      widget.onTransform(a);
      _close();
    });
  }

  // ---------- Dial gestures ----------
  double _angleAt(Offset local) {
    final v = local - Offset(_wrap / 2, _wrap / 2);
    return math.atan2(v.dx, -v.dy) * 180 / math.pi;
  }

  void _onDown(DragDownDetails d) {
    _snap.stop();
    final v = d.localPosition - Offset(_wrap / 2, _wrap / 2);
    final faceR = (80 / 240) * (_wrap * .645);
    _downOnFace = v.distance < faceR;
    _lastAngle = _angleAt(d.localPosition);
    _moved = 0;
  }

  void _onUpdate(DragUpdateDetails d) {
    var delta = _angleAt(d.localPosition) - _lastAngle;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _lastAngle += delta;
    _moved += delta.abs();
    if (_moved > 6) {
      if (!_isOpen) _activate();
      _setRot(_rot + delta);
    }
  }

  void _onEnd([DragEndDetails? _]) {
    if (_moved <= 6) {
      if (!_isOpen) {
        _activate();
      } else if (_downOnFace) {
        _transform();
      }
      return;
    }
    _animateTo((_rot / _step).round() * _step);
  }

  // ---------- Layout ----------
  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    // Dial size steps down on shorter screens; only the hologram stage flexes.
    final double wrap = h >= 760 ? 304 : (h >= 640 ? 272 : 244);
    final double gap = h >= 760 ? 26 : 20;
    const infoH = 104.0, hintH = 24.0, controlsH = 78.0;
    final stageH = math.max(150.0, math.min(250.0, h - infoH - gap - wrap - hintH - controlsH));
    final total = stageH + infoH + gap + wrap + hintH + controlsH;
    _wrap = wrap;

    final sel = aliens[_sel];
    final selOk = _unlocked(sel);

    return SizedBox(
      height: math.max(h, total),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              SizedBox(height: stageH, child: _buildStage(stageH, sel, selOk)),
              SizedBox(height: infoH, child: _buildInfo(sel, selOk)),
              SizedBox(height: gap),
              SizedBox(width: wrap, height: wrap, child: _buildWatch(wrap)),
              SizedBox(
                height: hintH,
                child: Center(
                  child: Text(
                    _isOpen ? 'Turn the dial to browse DNA  ·  slam the hourglass to transform' : 'Tap the Omnitrix to activate',
                    style: ui(11, color: AppColors.faint),
                  ),
                ),
              ),
              SizedBox(height: controlsH, child: _buildControls(sel, selOk)),
            ],
          ),
          // Transform flash
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (context, _) {
                  final t = _flash.value;
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  final o = t < .15 ? t / .15 : 1 - (t - .15) / .85;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, .3),
                        radius: 1.1,
                        colors: [
                          Colors.white.withValues(alpha: o),
                          AppColors.green.withValues(alpha: .95 * o),
                          AppColors.watch.withValues(alpha: .6 * o),
                          Colors.transparent,
                        ],
                        stops: const [0, .3, .6, 1],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage(double stageH, Alien sel, bool selOk) {
    final fig = math.min(220.0, stageH * .96);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() > 150) _turn(v < 0 ? 1 : -1);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Projector beam
          Positioned(
            bottom: -(infoBeamOverlap),
            child: AnimatedBuilder(
              animation: Listenable.merge([_open, _pulse]),
              builder: (context, _) => CustomPaint(
                size: Size(300, stageH + infoBeamOverlap),
                painter: _BeamPainter(_open.value, _pulse.value),
              ),
            ),
          ),
          SizedBox(
            width: fig,
            height: fig,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, anim) {
                if (!_isOpen) {
                  return ScaleTransition(
                    scale: Tween(begin: .6, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                    child: FadeTransition(opacity: anim, child: child),
                  );
                }
                // Hologram glitch: jitter sideways while fading in.
                return AnimatedBuilder(
                  animation: anim,
                  builder: (context, c) {
                    final t = anim.value;
                    final jitter = t < 1 ? math.sin(t * math.pi * 6) * 6 * (1 - t) : 0.0;
                    return Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(jitter, 0), child: c),
                    );
                  },
                  child: child,
                );
              },
              child: !_isOpen
                  ? KeyedSubtree(
                      key: ValueKey('idle-${widget.current.id}'),
                      child: CharacterView(alien: widget.current, mood: widget.mood, size: fig),
                    )
                  : selOk
                      ? _Hologram(key: ValueKey('holo-${sel.id}'), alien: sel, scan: _pulse)
                      : _Mystery(key: ValueKey('mystery-${sel.id}'), alien: sel),
            ),
          ),
        ],
      ),
    );
  }

  static const infoBeamOverlap = 30.0;

  Widget _buildInfo(Alien sel, bool selOk) {
    final a = _isOpen ? sel : widget.current;
    final ok = !_isOpen || selOk;
    final String status;
    if (!_isOpen) {
      status = 'CURRENT FORM';
    } else if (!ok) {
      status = 'UNLOCKS AT LV ${a.level}  ·  ${a.level - widget.level} TO GO';
    } else {
      status = a.id == widget.current.id ? 'CURRENT FORM' : 'DNA READY';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Chip2(ok ? a.species : 'Unknown DNA', color: ok ? a.color : AppColors.faint),
          const SizedBox(height: 8),
          Text(ok ? a.name : '? ? ?', style: heading(26), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(ok ? a.blurb : 'DNA sample not yet scanned.',
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(13.5, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(status,
              style: eyebrow(
                  size: 10, color: (_isOpen && (!ok || a.id == widget.current.id)) ? AppColors.green : AppColors.faint)),
        ],
      ),
    );
  }

  Widget _buildWatch(double wrap) {
    final face = wrap * .645;
    final r = wrap * .415;
    final c = wrap / 2;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
          () => _EagerPan(),
          (g) => g
            ..dragStartBehavior = DragStartBehavior.down
            ..onDown = _onDown
            ..onUpdate = _onUpdate
            ..onEnd = _onEnd
            ..onCancel = _onEnd,
        ),
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, _pulse, _slam]),
        builder: (context, _) {
          final o = Curves.easeOutBack.transform(_open.value).clamp(0.0, 1.2);
          final slam = math.sin(_slam.value * math.pi);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Ambient glow
              Positioned(
                left: c - 100,
                top: c - 100,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: .10 + .18 * _open.value),
                        blurRadius: 70,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              // DNA ring
              if (_open.value > 0)
                for (var i = 0; i < aliens.length; i++)
                  _thumbAt(i, c, r, o, _open.value),
              // The watch
              Positioned(
                left: c - face / 2,
                top: c - face / 2,
                child: CustomPaint(
                  size: Size.square(face),
                  painter: _DialPainter(
                    rot: _rot,
                    open: o,
                    pulse: _pulse.value,
                    slam: slam,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _thumbAt(int i, double c, double r, double o, double fade) {
    final a = aliens[i];
    final ang = _rad(i * _step + _rot);
    final selected = i == _sel;
    final ok = _unlocked(a);
    final scale = (0.4 + 0.6 * o) * (selected ? 1.2 : 1.0);
    const size = 40.0;
    return Positioned(
      left: c + r * math.sin(ang) - size / 2,
      top: c - r * math.cos(ang) - size / 2,
      child: Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.cardHi, AppColors.card],
              ),
              border: Border.all(
                width: 1.5,
                color: selected ? AppColors.green : (ok ? a.color.withValues(alpha: .45) : AppColors.border),
              ),
              boxShadow: selected ? [BoxShadow(color: AppColors.green.withValues(alpha: .6), blurRadius: 14)] : null,
            ),
            child: ClipOval(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: ok
                        ? Image.asset(a.asset, fit: BoxFit.contain)
                        : ColorFiltered(
                            colorFilter: const ColorFilter.mode(Color(0xFF050805), BlendMode.srcIn),
                            child: Image.asset(a.asset, fit: BoxFit.contain),
                          ),
                  ),
                  if (!ok)
                    Text('?',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                          shadows: const [Shadow(color: AppColors.green, blurRadius: 6)],
                        )),
                  if (a.id == widget.current.id)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.green,
                          boxShadow: [BoxShadow(color: AppColors.green, blurRadius: 5)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(Alien sel, bool selOk) {
    final String label;
    final bool locked = _isOpen && !selOk;
    if (!_isOpen) {
      label = 'ACTIVATE';
    } else if (!selOk) {
      label = 'LOCKED';
    } else {
      label = sel.id == widget.current.id ? 'CLOSE' : 'TRANSFORM';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _RoundButton(icon: Icons.chevron_left_rounded, enabled: _isOpen, onTap: () => _turn(-1)),
          const SizedBox(width: 12),
          Flexible(
            child: AnimatedBuilder(
              animation: _shake,
              builder: (context, child) {
                final t = _shake.value;
                final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 4) * 7 * (1 - t);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: _Cta(label: label, locked: locked, onTap: _isOpen ? _transform : _activate),
            ),
          ),
          const SizedBox(width: 12),
          _RoundButton(icon: Icons.chevron_right_rounded, enabled: _isOpen, onTap: () => _turn(1)),
        ],
      ),
    );
  }
}

/// A pan recogniser that wins the gesture arena immediately, so turning the dial
/// never scrolls the page underneath it.
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.locked, required this.onTap});
  final String label;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: locked
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFD7EC4A), AppColors.green],
                ),
          color: locked ? AppColors.cardHi : null,
          border: locked ? Border.all(color: AppColors.border) : null,
          boxShadow: locked ? null : [BoxShadow(color: AppColors.green.withValues(alpha: .35), blurRadius: 24)],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: locked ? AppColors.faint : const Color(0xFF0B0F05),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: enabled ? 1 : .3,
      child: Material(
        color: AppColors.cardHi,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(width: 50, height: 50, child: Icon(icon, color: AppColors.text, size: 26)),
        ),
      ),
    );
  }
}

/// Unlocked DNA, projected: the alien's shape lit in lime with moving scanlines.
class _Hologram extends StatelessWidget {
  const _Hologram({super.key, required this.alien, required this.scan});
  final Alien alien;
  final Animation<double> scan;

  // Map brightness to a lime ramp, keeping detail (dark -> deep lime, light -> pale lime).
  static const _lo = [110.0, 150.0, 20.0], _hi = [235.0, 252.0, 150.0];
  static final ColorFilter _tint = ColorFilter.matrix([
    for (var ch = 0; ch < 3; ch++) ...[
      (_hi[ch] - _lo[ch]) / 255 * .2126,
      (_hi[ch] - _lo[ch]) / 255 * .7152,
      (_hi[ch] - _lo[ch]) / 255 * .0722,
      0,
      _lo[ch],
    ],
    0, 0, 0, .92, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(alien.asset, fit: BoxFit.contain);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Glow
        ImageFiltered(
          imageFilter: dui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(AppColors.green.withValues(alpha: .55), BlendMode.srcIn),
            child: img,
          ),
        ),
        // Body with scanlines cut into it
        AnimatedBuilder(
          animation: scan,
          builder: (context, child) {
            final phase = scan.value * 8;
            return ShaderMask(
              blendMode: BlendMode.dstOut,
              shaderCallback: (b) => dui.Gradient.linear(
                Offset(0, phase),
                Offset(0, phase + 4),
                [Colors.black.withValues(alpha: .38), Colors.black.withValues(alpha: .38), Colors.transparent, Colors.transparent],
                [0, .5, .5, 1],
                TileMode.repeated,
              ),
              child: child,
            );
          },
          child: ColorFiltered(colorFilter: _tint, child: img),
        ),
      ],
    );
  }
}

/// Locked DNA: the same dark silhouette as a locked card, with a glowing "?".
class _Mystery extends StatelessWidget {
  const _Mystery({super.key, required this.alien});
  final Alien alien;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(alien.asset, fit: BoxFit.contain);
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: dui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(AppColors.green.withValues(alpha: .28), BlendMode.srcIn),
            child: img,
          ),
        ),
        ColorFiltered(colorFilter: const ColorFilter.mode(Color(0xFF040705), BlendMode.srcIn), child: img),
        Center(
          child: Text(
            '?',
            style: GoogleFonts.orbitron(
              fontSize: 60,
              fontWeight: FontWeight.w800,
              color: AppColors.green.withValues(alpha: .9),
              shadows: const [Shadow(color: AppColors.green, blurRadius: 18)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Light cone from the watch up to the hologram.
class _BeamPainter extends CustomPainter {
  _BeamPainter(this.open, this.pulse);
  final double open, pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (open <= 0) return;
    // Occasional flicker, like the show's projector.
    final flicker = (pulse > .47 && pulse < .5) ? 1.5 : ((pulse >= .5 && pulse < .53) ? .75 : 1.0);
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * .41, h)
      ..lineTo(w * .59, h)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = dui.Gradient.linear(
          Offset(0, h),
          Offset.zero,
          [
            AppColors.green.withValues(alpha: (.42 * open * flicker).clamp(0.0, 1.0)),
            AppColors.green.withValues(alpha: (.08 * open * flicker).clamp(0.0, 1.0)),
            Colors.transparent,
          ],
          [0, .6, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.open != open || old.pulse != pulse;
}

/// The watch: rotating bezel, steel ring, black face and the hourglass.
/// Drawn in a 240-unit space centred on the origin.
class _DialPainter extends CustomPainter {
  _DialPainter({required this.rot, required this.open, required this.pulse, required this.slam});
  final double rot, open, pulse, slam;

  static const _lime = AppColors.green;

  // Arc on a circle of radius r between two angles measured clockwise from 12 o'clock.
  void _arc(Canvas c, double r, double a0, double a1, Paint p) =>
      c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), _rad(a0 - 90), _rad(a1 - a0), false, p);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 240;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);

    // --- Rotating bezel ---
    canvas.save();
    canvas.rotate(_rad(rot));
    canvas.drawCircle(
      Offset.zero,
      116,
      Paint()
        ..shader = dui.Gradient.linear(
          const Offset(-116, -116),
          const Offset(116, 116),
          const [Color(0xFF3A403C), Color(0xFF151917), Color(0xFF2A302C)],
          const [0, .5, 1],
        ),
    );
    canvas.drawCircle(Offset.zero, 116, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black);
    final green = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..color = AppColors.watch;
    for (var i = 0; i < 8; i++) {
      _arc(canvas, 107, i * 45 + 3, i * 45 + 42, green);
    }
    final tick = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFC9D0CC);
    for (var i = 0; i < aliens.length; i++) {
      final a = _rad(i * _step);
      canvas.drawLine(Offset(113 * math.sin(a), -113 * math.cos(a)), Offset(119 * math.sin(a), -119 * math.cos(a)), tick);
    }
    canvas.drawCircle(Offset.zero, 99, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.black);
    canvas.restore();

    // --- Static steel ring ---
    canvas.drawCircle(Offset.zero, 90, Paint()..style = PaintingStyle.stroke..strokeWidth = 16..color = const Color(0xFF63696E));
    final hi = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = const Color(0xFFE8ECEF);
    _arc(canvas, 90, 35.5, 67.7, hi);
    _arc(canvas, 90, 215.5, 247.7, hi);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF050605);
    canvas.drawCircle(Offset.zero, 98.5, edge);
    canvas.drawCircle(Offset.zero, 81.5, edge);

    // --- Face: pops up when active, squishes when slammed ---
    canvas.save();
    final s = 1 + .07 * open - .08 * slam;
    canvas.scale(s);
    canvas.drawCircle(Offset.zero, 80, Paint()..color = const Color(0xFF050605));
    final hg = Path()
      ..moveTo(-50, -60)
      ..arcToPoint(const Offset(50, -60), radius: const Radius.circular(78))
      ..lineTo(8, -3)
      ..lineTo(-8, -3)
      ..close()
      ..moveTo(-50, 60)
      ..arcToPoint(const Offset(50, 60), radius: const Radius.circular(78), clockwise: false)
      ..lineTo(8, 3)
      ..lineTo(-8, 3)
      ..close();
    final glow = open.clamp(0.0, 1.0) * (.55 + .35 * (0.5 + 0.5 * math.sin(pulse * math.pi * 2)));
    if (glow > 0) {
      canvas.drawPath(
        hg,
        Paint()
          ..color = const Color(0xFFD6F050).withValues(alpha: glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    final bright = .2 * open.clamp(0.0, 1.0);
    canvas.drawPath(
      hg,
      Paint()
        ..shader = dui.Gradient.linear(
          const Offset(0, -78),
          const Offset(0, 78),
          [
            Color.lerp(const Color(0xFFD9EE52), Colors.white, bright)!,
            Color.lerp(const Color(0xFFB4CC22), const Color(0xFFD9EE52), bright)!,
          ],
        ),
    );
    canvas.restore();

    // --- Selection notch, pointing at the DNA at 12 o'clock ---
    if (open > 0) {
      final notch = Path()
        ..moveTo(-7, -83)
        ..lineTo(7, -83)
        ..lineTo(0, -96)
        ..close();
      canvas.drawPath(notch, Paint()..color = _lime.withValues(alpha: open.clamp(0.0, 1.0)));
      canvas.drawPath(
        notch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFF050605).withValues(alpha: open.clamp(0.0, 1.0)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.rot != rot || old.open != open || old.pulse != pulse || old.slam != slam;
}
