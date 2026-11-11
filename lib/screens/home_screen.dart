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
          title: Text('All $slots slots in use', style: heading(19)),
          content: Text(
            next == null
                ? 'You have every slot. Delete a habit to make room.'
                : 'Your companion unlocks another habit slot at Lv $next. Keep logging, or turn on "Unlock everything" in Settings.',
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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtLong(today).toUpperCase(),
                          style: ui(11, weight: FontWeight.w700, color: AppColors.muted, spacing: 1.3)),
                      const SizedBox(height: 4),
                      Text('Today', style: heading(34)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  icon: const Icon(Icons.settings_outlined, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Companion card
            Panel(
              padding: const EdgeInsets.fromLTRB(10, 10, 18, 14),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CharacterScreen())),
              child: Row(
                children: [
                  CharacterView(alien: al, mood: moodFor(s), size: 104),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.settings.petName, style: heading(21)),
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Lv ${p.level} · ${al.name}', style: ui(12.5, weight: FontWeight.w600, color: al.color)),
                            if (nx != null)
                              TextSpan(text: '  ·  next alien Lv ${nx.level}', style: ui(11.5, color: AppColors.faint)),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        XpBar(value: p.fraction, color: al.color),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Kpi(label: 'Score', value: score?.toString() ?? '—'),
                            _Kpi(label: 'Today', value: '${snap.doneToday}/${s.habits.length}'),
                            _Kpi(label: 'XP', value: '${p.xp}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SectionLabel('All habits', trailing: HeatLegend(color: AppColors.green)),
            Panel(
              child: Column(
                children: [
                  Heatmap(valueFor: snap.intensity, color: AppColors.green),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Kpi(label: 'Last 30 days', value: pct == null ? '—' : '$pct%'),
                      _Kpi(label: 'All-habit streak', value: '$run'),
                      _Kpi(label: 'Perfect days', value: '$perfect'),
                    ],
                  ),
                ],
              ),
            ),

            SectionLabel(
              'Habits',
              trailing: GestureDetector(
                onTap: () => _addHabit(context, s, p),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, size: 17, color: AppColors.green),
                    const SizedBox(width: 2),
                    Text('Add', style: ui(12.5, weight: FontWeight.w700, color: AppColors.green)),
                  ],
                ),
              ),
            ),
            if (s.habits.isEmpty)
              Panel(
                onTap: () => _addHabit(context, s, p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text('No habits yet. Tap to add your first.', style: ui(14, color: AppColors.muted)),
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
                  child: Text('Tap ✓ to log · long-press for notes & tags · tap a square to backfill',
                      style: ui(11.5, color: AppColors.faint)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: heading(17)),
            Text(label, style: ui(10.5, color: AppColors.muted)),
          ],
        ),
      );
}
