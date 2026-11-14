import 'package:flutter/material.dart';

import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/character.dart';
import '../widgets/omnitrix_dial.dart';
import 'hero_editor_screen.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final p = progressOf(s);
    final al = activeAlien(s, p.level);
    final nx = nextAlien(p.level, s.settings.unlockAll);
    final snap = Snapshot(s);
    final totalDays = snap.done.values.fold<int>(0, (a, d) => a + d.length);
    final slots = habitSlots(p.level, s.settings.unlockAll);
    final owned = aliens.where((a) => alienUnlocked(a, p.level, s.settings.unlockAll)).length;

    // Unlocks grouped by level: aliens + mission slots + colours.
    final ms = <int, List<String>>{};
    void add(int l, String t) => (ms[l] ??= []).add(t);
    for (final a in builtInAliens.skip(1)) {
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
      appBar: flatAppBar(
        'Omnitrix',
        titleWidget: Row(children: [
          const OmnitrixLogo(size: 26),
          const SizedBox(width: 10),
          Text('OMNITRIX', style: heading(17).copyWith(letterSpacing: 3)),
        ]),
        actions: [
          Center(child: Chip2('Lv ${p.level}', filled: true)),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, box) => ListView(
          padding: EdgeInsets.zero,
          children: [
            OmnitrixDial(
              current: al,
              mood: moodFor(s),
              level: p.level,
              unlockAll: s.settings.unlockAll,
              height: box.maxHeight,
              onTransform: (a) {
                s.updateSettings((x) => x.alien = a.id);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('Transformed into ${a.name}')));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 18),
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
                  SectionLabel(
                    'Your heroes',
                    trailing: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeroEditorScreen())),
                      child: Text('+ ADD', style: heading(12, color: AppColors.green)),
                    ),
                  ),
                  _HeroList(heroes: customHeroes, current: al),
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

/// Custom heroes made on this phone. Always unlocked, and on the dial with the aliens.
class _HeroList extends StatelessWidget {
  const _HeroList({required this.heroes, required this.current});
  final List<Alien> heroes;
  final Alien current;

  void _open(BuildContext context, [Alien? h]) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => HeroEditorScreen(hero: h)));

  @override
  Widget build(BuildContext context) {
    if (heroes.isEmpty) {
      return Panel(
        onTap: () => _open(context),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.green.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add yourself to the Omnitrix', style: ui(14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('Your own photo as a free form. It stays on this phone.',
                      style: ui(12, color: AppColors.muted, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Panel(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final h in heroes)
            InkWell(
              onTap: () => _open(context, h),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardHi,
                        border: Border.all(color: h.color.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: ClipOval(child: Image(image: h.image, fit: BoxFit.contain)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: ui(14.5, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(h == current ? '${h.species} · Active' : h.species,
                              style: ui(12, color: h == current ? AppColors.green : AppColors.muted)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_rounded, size: 16, color: AppColors.faint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
