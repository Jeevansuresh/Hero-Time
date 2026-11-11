import 'package:flutter/material.dart';

import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/heatmap.dart';
import 'habit_editor_screen.dart';
import 'log_sheet.dart';

class HabitDetailScreen extends StatelessWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final h = s.habitById(habitId);
    if (h == null) return const Scaffold();

    final done = s.doneDays(h.id);
    final today = todayKey();
    final st = statsFor(h, done, today);
    final color = Color(h.color);
    final start = startDayOf(h, done);
    final entries = s.entriesFor(h.id).toList()..sort((a, b) => b.day.compareTo(a.day));

    // Tag breakdown, last 30 days (e.g. which muscles you've hit).
    final counts = <String, int>{};
    for (final e in entries) {
      if (e.day < today - 29 || !e.done) continue;
      for (final t in e.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final tagRows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = tagRows.isEmpty ? 1 : tagRows.first.value;
    final untouched = h.tags.where((t) => !counts.containsKey(t)).toList();

    return AppScaffold(
      appBar: flatAppBar(
        h.name,
        titleWidget: Row(
          children: [
            Text(h.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Flexible(child: Text(h.name, overflow: TextOverflow.ellipsis, style: heading(20))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HabitEditorScreen(habit: h)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
        children: [
          Text('${h.isQuit ? 'Quit' : 'Build'} · ${h.goalText}', style: ui(13.5, color: AppColors.muted)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Streak', value: '${st.streak}', unit: st.unitLong, color: color, hot: true)),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'Best', value: '${st.best}', unit: st.weekly ? 'weeks' : 'days', color: color)),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'Score', value: st.score?.toString() ?? '—', unit: '/ 100', color: color)),
              const SizedBox(width: 10),
              Expanded(child: _StatTile(label: 'Total', value: '${st.total}', unit: h.isQuit ? 'clean' : 'days', color: color)),
            ],
          ),
          SectionLabel('Contributions', trailing: Text('Tap a day to log', style: ui(11, color: AppColors.faint))),
          Panel(
            child: Heatmap(
              weeks: 30,
              color: color,
              valueFor: (d) => d < start ? -1 : (done.contains(d) ? 1 : 0),
              onTap: (d) => showLogSheet(context, h, d),
            ),
          ),
          if (tagRows.isNotEmpty) ...[
            const SectionLabel('Last 30 days'),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in tagRows) _TagBar(label: r.key, count: r.value, max: maxCount, color: color),
                  if (untouched.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Not hit yet: ${untouched.join(', ')}', style: ui(12, color: AppColors.faint, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
          const SectionLabel('Log'),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Nothing logged yet. Tap the check on the home screen, or any square above.',
                  style: ui(13.5, color: AppColors.muted, height: 1.4)),
            ),
          for (final e in entries.take(150))
            _EntryTile(entry: e, habit: h, color: color, onTap: () => showLogSheet(context, h, e.day)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.unit, required this.color, this.hot = false});
  final String label, value, unit;
  final Color color;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        color: hot ? color.withValues(alpha: 0.10) : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hot ? color.withValues(alpha: 0.35) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: ui(9.5, weight: FontWeight.w700, color: AppColors.muted, spacing: 1.1)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: heading(24))),
          Text(unit, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(10.5, color: AppColors.faint)),
        ],
      ),
    );
  }
}

class _TagBar extends StatelessWidget {
  const _TagBar({required this.label, required this.count, required this.max, required this.color});
  final String label;
  final int count, max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label, overflow: TextOverflow.ellipsis, style: ui(13))),
          Expanded(child: XpBar(value: count / max, color: color, height: 8)),
          SizedBox(
            width: 30,
            child: Text('$count', textAlign: TextAlign.right, style: ui(13, weight: FontWeight.w600, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.habit, required this.color, required this.onTap});
  final Entry entry;
  final Habit habit;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: e.done ? color : AppColors.danger),
                ),
                const SizedBox(width: 10),
                Text(fmtDay(e.day), style: ui(14, weight: FontWeight.w600)),
                const Spacer(),
                Text(e.done ? habit.doneLabel : habit.missLabel, style: ui(12, color: AppColors.muted)),
              ],
            ),
            if (e.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final t in e.tags) TagPill(label: t, selected: true, color: color, small: true)],
              ),
            ],
            if (e.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(e.note, style: ui(13.5, color: AppColors.muted, height: 1.45)),
            ],
          ],
        ),
      ),
    );
  }
}
