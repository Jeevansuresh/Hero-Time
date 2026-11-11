import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sfx.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/character.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = progressOf(s);
    final al = activeAlien(s, p.level);
    final color = al.color;
    final nx = nextAlien(p.level, s.settings.unlockAll);
    final snap = Snapshot(s);
    final totalDays = snap.done.values.fold<int>(0, (a, d) => a + d.length);
    final slots = habitSlots(p.level, s.settings.unlockAll);
    final owned = aliens.where((a) => alienUnlocked(a, p.level, s.settings.unlockAll)).length;

    // Unlocks grouped by level: aliens + mission slots + colours.
    final ms = <int, List<String>>{};
    void add(int l, String t) => (ms[l] ??= []).add(t);
    for (final a in aliens.skip(1)) {
      add(a.level, 'alien:${a.name}');
    }
    for (final l in slotLevels) {
      add(l, '+1 mission slot');
    }
    for (final l in paletteUnlockLevel) {
      if (l > 1) add(l, 'New colour');
    }
    final levels = ms.keys.toList()..sort();

    return AppScaffold(
      appBar: flatAppBar('Omnitrix', titleWidget: Row(children: [
        const OmnitrixLogo(size: 26),
        const SizedBox(width: 10),
        Text('OMNITRIX', style: heading(17).copyWith(letterSpacing: 3)),
      ])),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 56),
        children: [
          Center(child: _TransformStage(alien: al, mood: moodFor(s))),
          const SizedBox(height: 4),
          Center(child: Chip2(al.species, color: color)),
          const SizedBox(height: 10),
          Center(child: Text(al.name, style: heading(32))),
          const SizedBox(height: 6),
          Center(child: Text(al.blurb, textAlign: TextAlign.center, style: ui(14, color: AppColors.muted))),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () async {
                final name = await promptText(context, title: 'Name your hero', initial: s.settings.petName);
                if (name != null && name.trim().isNotEmpty) {
                  s.updateSettings((x) => x.petName = name.trim());
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('WIELDER  ', style: eyebrow(size: 10)),
                  Text(s.settings.petName, style: ui(14, weight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_rounded, size: 14, color: AppColors.faint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Panel(
            glow: AppColors.green,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${p.xp}', style: heading(26)),
                    const SizedBox(width: 6),
                    Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('XP', style: eyebrow())),
                    const Spacer(),
                    Chip2('Lv ${p.level}', filled: true),
                  ],
                ),
                const SizedBox(height: 14),
                XpBar(value: p.fraction, color: AppColors.green, height: 10),
                const SizedBox(height: 10),
                Text(
                  '${p.next - p.xp} XP to Lv ${p.level + 1}${nx != null ? '  ·  ${nx.name} unlocks at Lv ${nx.level}' : ''}',
                  style: ui(12, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Mini(label: 'DNA', value: '$owned/${aliens.length}'),
                    _Mini(label: 'Check-ins', value: '$totalDays'),
                    _Mini(label: 'Slots', value: s.settings.unlockAll ? '∞' : '${s.habits.length}/$slots'),
                  ],
                ),
              ],
            ),
          ),
          SectionLabel('DNA samples', trailing: Text('Tap to transform', style: ui(11, color: AppColors.faint))),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
            children: [
              for (final a in aliens)
                _AlienTile(
                  alien: a,
                  unlocked: alienUnlocked(a, p.level, s.settings.unlockAll),
                  active: a.id == al.id,
                  mood: a.id == al.id ? moodFor(s) : Mood.neutral,
                  onTap: () {
                    final m = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
                    if (!alienUnlocked(a, p.level, s.settings.unlockAll)) {
                      final left = a.level - p.level;
                      m.showSnackBar(SnackBar(
                          content: Text('DNA locked. Unlocks at Lv ${a.level}, $left more level${left == 1 ? '' : 's'} to go.')));
                      return;
                    }
                    if (a.id == al.id) return;
                    Sfx.play('transform');
                    s.updateSettings((x) => x.alien = a.id);
                    m.showSnackBar(SnackBar(content: Text('Transformed into ${a.name}')));
                  },
                ),
            ],
          ),
          const SectionLabel('Charging the Omnitrix'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Rule(xp: '+$xpPerDay', text: 'every mission completed for the day'),
                const _Rule(xp: '+$xpPerDetail', text: 'when you add a note or tags'),
                const _Rule(xp: '+$xpPerWeekGoal', text: 'for each mission that hits its weekly goal'),
                const SizedBox(height: 8),
                Text('XP is recalculated from your log, so edits and backfills always stay honest.',
                    style: ui(12, color: AppColors.faint, height: 1.45)),
              ],
            ),
          ),
          const SectionLabel('Unlock path'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final l in levels)
                  _Milestone(
                    level: l,
                    text: ms[l]!
                        .map((x) => x.startsWith('alien:')
                            ? ((p.level >= l || s.settings.unlockAll) ? x.substring(6) : 'Unknown DNA')
                            : x)
                        .join('  ·  '),
                    reached: p.level >= l || s.settings.unlockAll,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The alien in front of a slowly turning Omnitrix face. Flashes green on transform.
class _TransformStage extends StatefulWidget {
  const _TransformStage({required this.alien, required this.mood});
  final Alien alien;
  final Mood mood;

  @override
  State<_TransformStage> createState() => _TransformStageState();
}

class _TransformStageState extends State<_TransformStage> with TickerProviderStateMixin {
  late final AnimationController _flash =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700), value: 1);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void didUpdateWidget(_TransformStage old) {
    super.didUpdateWidget(old);
    if (old.alien.id != widget.alien.id) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 280.0;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flash, _spin]),
        builder: (context, child) {
          final t = _flash.value;
          final burst = t >= 1 ? 0.0 : (1 - t);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _spin.value * math.pi * 2,
                child: OmnitrixLogo(size: size * 0.95, glow: false, opacity: 0.10 + 0.5 * burst),
              ),
              Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.10 + 0.6 * burst),
                      blurRadius: 50 + 60 * burst,
                    ),
                  ],
                ),
              ),
              Transform.scale(scale: 1 - 0.6 * burst * (1 - burst), child: child),
              if (burst > 0)
                IgnorePointer(
                  child: Container(
                    width: size * (0.2 + 1.3 * t),
                    height: size * (0.2 + 1.3 * t),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        Colors.white.withValues(alpha: 0.7 * burst),
                        AppColors.green.withValues(alpha: 0.6 * burst),
                        AppColors.green.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        },
        child: CharacterView(alien: widget.alien, mood: widget.mood, size: 220),
      ),
    );
  }
}

class _AlienTile extends StatelessWidget {
  const _AlienTile({
    required this.alien,
    required this.unlocked,
    required this.active,
    required this.mood,
    required this.onTap,
  });
  final Alien alien;
  final bool unlocked, active;
  final Mood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = alien.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? [c.withValues(alpha: active ? 0.22 : 0.10), AppColors.card]
                : [AppColors.cardHi, AppColors.card],
          ),
          border: Border.all(
            color: active ? c.withValues(alpha: 0.9) : (unlocked ? c.withValues(alpha: 0.18) : AppColors.border),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: -4)] : null,
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: active
                  ? Chip2('Active', color: c, filled: true)
                  : (unlocked
                      ? const SizedBox(height: 20)
                      : const Padding(
                          padding: EdgeInsets.all(3),
                          child: Icon(Icons.lock_rounded, size: 14, color: AppColors.faint),
                        )),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, cons) => CharacterView(
                  key: ValueKey('${alien.id}-$unlocked'),
                  alien: alien,
                  mood: mood,
                  size: cons.biggest.shortestSide,
                  locked: !unlocked,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(unlocked ? alien.name : '? ? ?',
                style: heading(14, color: unlocked ? AppColors.text : AppColors.faint)),
            const SizedBox(height: 3),
            Text(
              unlocked ? alien.species.toUpperCase() : 'UNLOCKS AT LV ${alien.level}',
              style: eyebrow(size: 8.5, color: unlocked ? c.withValues(alpha: 0.85) : AppColors.faint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: heading(20)),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: eyebrow(size: 9)),
          ],
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.xp, required this.text});
  final String xp, text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(xp, style: heading(15, color: AppColors.green))),
            Expanded(child: Text(text, style: ui(13.5))),
          ],
        ),
      );
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.level, required this.text, required this.reached});
  final int level;
  final String text;
  final bool reached;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? AppColors.green.withValues(alpha: 0.14) : AppColors.cardHi,
                border: Border.all(color: reached ? AppColors.green.withValues(alpha: 0.6) : AppColors.border),
              ),
              child: Text('$level', style: heading(13, color: reached ? AppColors.green : AppColors.faint)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: ui(13.5, color: reached ? AppColors.text : AppColors.muted))),
            Icon(
              reached ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 18,
              color: reached ? AppColors.green : AppColors.faint,
            ),
          ],
        ),
      );
}
