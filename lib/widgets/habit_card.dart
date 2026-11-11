import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../screens/habit_detail_screen.dart';
import '../screens/log_sheet.dart';
import '../stats.dart';
import '../store.dart';
import '../sfx.dart';
import '../theme.dart';
import 'heatmap.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit, required this.done});
  final Habit habit;
  final Set<int> done;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final h = habit;
    final today = todayKey();
    final st = statsFor(h, done, today);
    final isDone = done.contains(today);
    final missed = s.entry(h.id, today)?.done == false;
    final color = Color(h.color);
    final goalMet = st.weekDone >= h.target;

    final sub = StringBuffer('${st.weekDone}/${h.target} ${h.isQuit ? 'clean' : ''} this week'.replaceAll('  ', ' '));
    if (st.streak > 0) sub.write('  ·  🔥 ${st.streak}${st.unitShort}');

    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.id)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(h.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(h.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(16, weight: FontWeight.w600)),
                        ),
                        if (goalMet) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified_rounded, size: 15, color: color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(sub.toString(), style: ui(12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              _CheckButton(
                done: isDone,
                missed: missed,
                quit: h.isQuit,
                color: color,
                onTap: () {
                  HapticFeedback.lightImpact();
                  final before = st.weekDone;
                  final nowDone = s.toggleToday(h);
                  Sfx.play(nowDone ? (before < h.target && before + 1 >= h.target ? 'goal' : 'check') : 'undo');
                  final m = ScaffoldMessenger.of(context);
                  m.hideCurrentSnackBar();
                  if (nowDone) {
                    m.showSnackBar(SnackBar(
                      duration: const Duration(seconds: 3),
                      content: Text('${h.emoji}  ${h.name} logged'),
                      action: SnackBarAction(
                        label: h.tags.isNotEmpty ? 'Add details' : 'Add note',
                        onPressed: () => showLogSheet(context, h, today),
                      ),
                    ));
                  }
                },
                onLongPress: () => showLogSheet(context, h, today),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Heatmap(
            weeks: 26,
            cell: 11,
            gap: 3,
            color: color,
            valueFor: (d) => d < startDayOf(h, done) ? -1 : (done.contains(d) ? 1 : 0),
            onTap: (d) => showLogSheet(context, h, d),
          ),
        ],
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.done,
    required this.missed,
    required this.quit,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });
  final bool done, missed, quit;
  final Color color;
  final VoidCallback onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final icon = missed ? Icons.close_rounded : (quit ? Icons.shield_rounded : Icons.check_rounded);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : Colors.transparent,
          border: Border.all(
            color: done ? color : (missed ? AppColors.danger.withValues(alpha: 0.6) : color.withValues(alpha: 0.35)),
            width: 2,
          ),
          boxShadow: done ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14)] : null,
        ),
        child: Icon(
          icon,
          size: 22,
          color: done ? const Color(0xFF0B0B0F) : (missed ? AppColors.danger : color.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}
