import 'package:flutter/material.dart';

import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/character.dart';
import '../widgets/habit_card.dart';
import '../widgets/heatmap.dart';
import 'character_screen.dart';
import 'habit_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _addHabit(BuildContext context, AppStore s, Progress p) {
    final slots = habitSlots(p.level, s.settings.unlockAll);
    if (s.habits.length >= slots) {
      final next = nextSlotLevel(p.level);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardHi,
          surfaceTintColor: Colors.transparent,
          title: Text('All $slots mission slots in use', style: heading(19)),
          content: Text(
            next == null
                ? 'You have every slot. Delete a habit to make room.'
                : 'The Omnitrix unlocks another mission slot at Lv $next. Keep logging, or turn on "Unlock everything" in Settings.',
            style: ui(14, color: AppColors.muted, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Got it', style: ui(14, weight: FontWeight.w700))),
          ],
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitEditorScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final snap = Snapshot(s);
    final p = progressOf(s);
    final al = activeAlien(s, p.level);
    final nx = nextAlien(p.level, s.settings.unlockAll);
    final score = snap.overallScore;
    final today = snap.today;

    // Overall consistency across every habit.
    var sum = 0.0, days = 0, perfect = 0, run = 0;
    for (var d = today - 29; d <= today; d++) {
      final v = snap.intensity(d);
      if (v < 0 || (d == today && v < 1)) continue;
      sum += v;
      days++;
    }
    for (var d = today - 364; d <= today; d++) {
      if (snap.intensity(d) >= 1) perfect++;
    }
    for (var d = snap.intensity(today) >= 1 ? today : today - 1; snap.intensity(d) >= 1; d--) {
      run++;
    }
    final pct = days == 0 ? null : (sum / days * 100).round();

    return AppScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 56),
          children: [
            // Brand bar
            Row(
              children: [
                const OmnitrixLogo(size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HERO TIME', style: heading(15, color: AppColors.green).copyWith(letterSpacing: 3)),
                      const SizedBox(height: 2),
                      Text(fmtLong(today).toUpperCase(), style: eyebrow(size: 10)),
                    ],
                  ),
                ),
                _RoundIcon(
                  icon: Icons.tune_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text('Welcome back,', style: ui(15, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(s.settings.petName, style: heading(34)),
            const SizedBox(height: 20),

            // Hero card: the active alien
            Panel(
              glow: al.color,
              padding: EdgeInsets.zero,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterScreen())),
              child: Stack(
                children: [
                  // Watermark watch face
                  Positioned(
                    right: -60,
                    top: -50,
                    child: Transform.rotate(
                      angle: -0.25,
                      child: const OmnitrixLogo(size: 230, glow: false, opacity: 0.06),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.7, -0.2),
                          radius: 0.9,
                          colors: [al.color.withValues(alpha: 0.18), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 14, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CharacterView(alien: al, mood: moodFor(s), size: 128),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Chip2('Lv ${p.level}', color: AppColors.green, filled: true),
                                    const SizedBox(width: 6),
                                    Flexible(child: Chip2(al.species, color: al.color)),
                                  ]),
                                  const SizedBox(height: 10),
                                  Text(al.name, style: heading(24)),
                                  const SizedBox(height: 4),
                                  Text(al.blurb, style: ui(12.5, color: AppColors.muted, height: 1.35)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('OMNITRIX CHARGE', style: eyebrow(size: 9.5)),
                                  const Spacer(),
                                  Text(nx == null ? 'All DNA unlocked' : 'Next DNA at Lv ${nx.level}',
                                      style: ui(11, color: AppColors.faint, weight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              XpBar(value: p.fraction, color: AppColors.green),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _Kpi(label: 'Score', value: score?.toString() ?? '—'),
                                  const _VDivider(),
                                  _Kpi(label: 'Today', value: '${snap.doneToday}/${s.habits.length}'),
                                  const _VDivider(),
                                  _Kpi(label: 'XP', value: '${p.xp}'),
                                ],
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

            const SectionLabel('Mission log', trailing: HeatLegend(color: AppColors.green)),
            Panel(
              child: Column(
                children: [
                  Heatmap(valueFor: snap.intensity, color: AppColors.green),
                  const SizedBox(height: 16),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Kpi(label: '30 days', value: pct == null ? '—' : '$pct%'),
                      const _VDivider(),
                      _Kpi(label: 'Streak', value: '$run'),
                      const _VDivider(),
                      _Kpi(label: 'Perfect', value: '$perfect'),
                    ],
                  ),
                ],
              ),
            ),

            SectionLabel(
              'Missions',
              trailing: GestureDetector(
                onTap: () => _addHabit(context, s, p),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_rounded, size: 16, color: AppColors.green),
                      const SizedBox(width: 3),
                      Text('NEW', style: eyebrow(size: 10, color: AppColors.green).copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            if (s.habits.isEmpty)
              Panel(
                onTap: () => _addHabit(context, s, p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text('No missions yet. Tap to add your first.', style: ui(14, color: AppColors.muted)),
                  ),
                ),
              ),
            for (final h in s.habits)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HabitCard(habit: h, done: snap.done[h.id]!),
              ),
            if (s.habits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text('Tap ✓ to log  ·  hold for notes & tags  ·  tap a square to backfill',
                      style: ui(11, color: AppColors.faint)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: heading(18)),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: eyebrow(size: 9)),
          ],
        ),
      );
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 28, color: AppColors.border);
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardHi,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 20, color: AppColors.text)),
        ),
      );
}
