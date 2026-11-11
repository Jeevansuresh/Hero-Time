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

    // Unlocks grouped by level: aliens + habit slots + colours.
    final ms = <int, List<String>>{};
    void add(int l, String t) => (ms[l] ??= []).add(t);
    for (final a in aliens.skip(1)) {
      add(a.level, 'alien:${a.name}');
    }
    for (final l in slotLevels) {
      add(l, '+1 habit slot');
    }
    for (final l in paletteUnlockLevel) {
      if (l > 1) add(l, 'New colour');
    }
    final levels = ms.keys.toList()..sort();

    return Scaffold(
      appBar: flatAppBar('Companion'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          Center(child: CharacterView(alien: al, mood: moodFor(s), size: 220)),
          Center(
            child: GestureDetector(
              onTap: () async {
                final name = await promptText(context, title: 'Name your companion', initial: s.settings.petName);
                if (name != null && name.trim().isNotEmpty) {
                  s.updateSettings((x) => x.petName = name.trim());
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.settings.petName, style: heading(30)),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_rounded, size: 16, color: AppColors.faint),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: Text('Lv ${p.level} · in ${al.name} form', style: ui(14, weight: FontWeight.w600, color: color))),
          const SizedBox(height: 6),
          Center(child: Text(al.blurb, textAlign: TextAlign.center, style: ui(13.5, color: AppColors.muted))),
          const SizedBox(height: 22),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${p.xp} XP', style: heading(18)),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${p.next - p.xp} to Lv ${p.level + 1}${nx != null ? ' · ${nx.name} at Lv ${nx.level}' : ''}',
                        textAlign: TextAlign.right,
                        style: ui(12.5, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                XpBar(value: p.fraction, color: color, height: 9),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Mini(label: 'Aliens', value: '$owned/${aliens.length}'),
                    _Mini(label: 'Check-ins', value: '$totalDays'),
                    _Mini(label: 'Habit slots', value: s.settings.unlockAll ? '∞' : '${s.habits.length}/$slots'),
                  ],
                ),
              ],
            ),
          ),
          SectionLabel('Aliens', trailing: Text('Tap one to transform', style: ui(11, color: AppColors.faint))),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
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
                          content: Text('This alien unlocks at Lv ${a.level}. $left more level${left == 1 ? '' : 's'} to go.')));
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
          const SectionLabel('How you level up'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Rule(xp: '+$xpPerDay', text: 'every successful day'),
                const _Rule(xp: '+$xpPerDetail', text: 'when you add a note or tags'),
                const _Rule(xp: '+$xpPerWeekGoal', text: 'for each habit that hits its weekly goal'),
                const SizedBox(height: 6),
                Text('XP is recalculated from your log, so edits and backfills always stay honest.',
                    style: ui(12, color: AppColors.faint, height: 1.4)),
              ],
            ),
          ),
          const SectionLabel('Unlocks'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final l in levels)
                  _Milestone(
                    level: l,
                    text: ms[l]!
                        .map((x) => x.startsWith('alien:')
                            ? ((p.level >= l || s.settings.unlockAll) ? x.substring(6) : 'New alien')
                            : x)
                        .join('  ·  '),
                    reached: p.level >= l || s.settings.unlockAll,
                    color: color,
                  ),
              ],
            ),
          ),
        ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? alien.color.withValues(alpha: 0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? alien.color.withValues(alpha: 0.8) : AppColors.border, width: 1.3),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => CharacterView(
                  key: ValueKey('${alien.id}-$unlocked'),
                  alien: alien,
                  mood: mood,
                  size: c.biggest.shortestSide,
                  locked: !unlocked,
                ),
              ),
            ),
            Text(unlocked ? alien.name : '???',
                style: ui(13.5, weight: FontWeight.w700, color: unlocked ? AppColors.text : AppColors.faint)),
            const SizedBox(height: 2),
            Text(
              active ? 'Active' : (unlocked ? 'Unlocked' : 'Lv ${alien.level}'),
              style: ui(11, color: AppColors.muted),
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
            const SizedBox(height: 2),
            Text(label, style: ui(11.5, color: AppColors.muted)),
          ],
        ),
      );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.xp, required this.text});
  final String xp, text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(width: 48, child: Text(xp, style: ui(14, weight: FontWeight.w700, color: AppColors.green))),
            Expanded(child: Text(text, style: ui(13.5))),
          ],
        ),
      );
}

class _Milestone extends StatelessWidget {
  const _Milestone({required this.level, required this.text, required this.reached, required this.color});
  final int level;
  final String text;
  final bool reached;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reached ? color.withValues(alpha: 0.16) : AppColors.cardHi,
                border: Border.all(color: reached ? color.withValues(alpha: 0.6) : AppColors.border),
              ),
              child: Text('$level', style: ui(13, weight: FontWeight.w700, color: reached ? color : AppColors.faint)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: ui(13.5, color: reached ? AppColors.text : AppColors.muted))),
            Icon(
              reached ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
              size: 18,
              color: reached ? color : AppColors.faint,
            ),
          ],
        ),
      );
}
