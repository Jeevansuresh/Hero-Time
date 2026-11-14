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

/// Tick (done) or cross (missed) [day] for [h], with sound, haptics and a snackbar.
/// Tapping the answer that's already set clears the day. If that day has a note or
/// tags, the log sheet opens instead so nothing is thrown away by accident.
void markDay(BuildContext context, Habit h, int day, bool done) {
  final s = StoreScope.read(context);
  final cur = s.entry(h.id, day);
  if (cur != null && cur.done == done && cur.hasDetails) {
    showLogSheet(context, h, day);
    return;
  }
  final before = statsFor(h, s.doneDays(h.id), todayKey()).weekDone;
  final after = s.mark(h, day, done);
  final sameWeek = weekStartOf(day) == weekStartOf(todayKey());
  HapticFeedback.lightImpact();
  Sfx.play(switch (after) {
    true => sameWeek && before < h.target && before + 1 >= h.target ? 'goal' : 'check',
    false => 'slip',
    null => 'undo',
  });

  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  if (after == null) return;
  final when = day == todayKey() ? '' : ' for ${fmtDay(day)}';
  m.showSnackBar(SnackBar(
    persist: false, // snackbars with an action otherwise stay until tapped
    duration: const Duration(seconds: 3),
    content: Text('${h.emoji}  ${h.name}: ${after ? h.doneLabel : h.missLabel}$when'),
    action: SnackBarAction(
      label: after && h.tags.isNotEmpty ? 'Add details' : 'Add note',
      onPressed: () => showLogSheet(context, h, day),
    ),
  ));
}

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
    final state = s.entry(h.id, today)?.done; // true done, false missed, null not logged
    final color = Color(h.color);
    final goalMet = st.weekDone >= h.target;
    final start = startDayOf(h, done);

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
              const SizedBox(width: 8),
              MarkButton(
                done: false,
                selected: state == false,
                dimmed: state == true,
                color: AppColors.danger,
                tooltip: h.missLabel,
                onTap: () => markDay(context, h, today, false),
                onLongPress: () => showLogSheet(context, h, today),
              ),
              const SizedBox(width: 8),
              MarkButton(
                done: true,
                quit: h.isQuit,
                selected: state == true,
                dimmed: state == false,
                color: color,
                tooltip: h.doneLabel,
                onTap: () => markDay(context, h, today, true),
                onLongPress: () => showLogSheet(context, h, today),
              ),
            ],
          ),
          const SizedBox(height: 14),
          WeekStrip(habit: h, start: start),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Heatmap(
            weeks: 26,
            cell: 11,
            gap: 3,
            color: color,
            valueFor: (d) => d < start ? -1 : (done.contains(d) ? 1 : 0),
            missedFor: (d) => s.entry(h.id, d)?.done == false,
            onTap: (d) => showLogSheet(context, h, d),
          ),
        ],
      ),
    );
  }
}

/// Round ✓ or ✕ button. Lit when [selected], faded when the other answer is set.
class MarkButton extends StatelessWidget {
  const MarkButton({
    super.key,
    required this.done,
    required this.selected,
    required this.dimmed,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.onLongPress,
    this.quit = false,
    this.size = 42,
  });
  final bool done, selected, dimmed, quit;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = done ? (quit ? Icons.shield_rounded : Icons.check_rounded) : Icons.close_rounded;
    return Semantics(
      button: true,
      selected: selected,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: dimmed ? 0.35 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? color : Colors.transparent,
              border: Border.all(color: selected ? color : color.withValues(alpha: 0.4), width: 2),
              boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14)] : null,
            ),
            child: Icon(
              icon,
              size: size * 0.5,
              color: selected ? const Color(0xFF0B0B0F) : color.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

/// The last 7 days, oldest on the left. Tap a day to tick or cross it.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.habit, required this.start});
  final Habit habit;
  final int start;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final today = todayKey();
    final color = Color(habit.color);
    return Row(
      children: [
        for (var d = today - 6; d <= today; d++)
          Expanded(
            child: _DayDot(
              day: d,
              isToday: d == today,
              state: s.entry(habit.id, d)?.done,
              color: color,
              onTap: () => showDayPicker(context, habit, d),
            ),
          ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.isToday, required this.state, required this.color, required this.onTap});
  final int day;
  final bool isToday;
  final bool? state;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = dayDate(day);
    final c = state == false ? AppColors.danger : color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Text(isToday ? 'Today' : weekdayShort[date.weekday - 1].substring(0, 2),
              style: ui(10, weight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? AppColors.text : AppColors.faint)),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == null ? Colors.transparent : c.withValues(alpha: state! ? 1 : 0.16),
              border: Border.all(
                color: state == null
                    ? (isToday ? AppColors.text.withValues(alpha: 0.5) : AppColors.border)
                    : c.withValues(alpha: state! ? 1 : 0.7),
                width: 1.4,
              ),
            ),
            child: state == null
                ? Text('${date.day}', style: ui(11.5, weight: FontWeight.w600, color: AppColors.muted))
                : Icon(state! ? Icons.check_rounded : Icons.close_rounded,
                    size: 16, color: state! ? const Color(0xFF0B0B0F) : AppColors.danger),
          ),
        ],
      ),
    );
  }
}

/// Small sheet for one day: big ✓ / ✕, plus a link to the full log sheet.
Future<void> showDayPicker(BuildContext context, Habit h, int day) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.cardHi,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheet) {
      final s = StoreScope.of(sheet);
      final state = s.entry(h.id, day)?.done;
      final color = Color(h.color);
      void pick(bool done) {
        Navigator.pop(sheet);
        markDay(context, h, day, done);
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${h.emoji}  ${h.name}', style: heading(19)),
            const SizedBox(height: 3),
            Text('${fmtDay(day)}${day == todayKey() ? ' · Today' : ''}', style: ui(13, color: AppColors.muted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _BigChoice(
                    label: h.missLabel,
                    icon: Icons.close_rounded,
                    selected: state == false,
                    color: AppColors.danger,
                    onTap: () => pick(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BigChoice(
                    label: h.doneLabel,
                    icon: h.isQuit ? Icons.shield_rounded : Icons.check_rounded,
                    selected: state == true,
                    color: color,
                    onTap: () => pick(true),
                  ),
                ),
              ],
            ),
            if (state != null) ...[
              const SizedBox(height: 6),
              Text('Tap the lit one again to clear this day.',
                  textAlign: TextAlign.center, style: ui(11.5, color: AppColors.faint)),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                showLogSheet(context, h, day);
              },
              icon: Icon(Icons.edit_note_rounded, color: color),
              label: Text('Notes, tags or another date', style: ui(14, weight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      );
    },
  );
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.label, required this.icon, required this.selected, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 8),
            Text(label, style: ui(16, weight: FontWeight.w700, color: selected ? AppColors.text : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
