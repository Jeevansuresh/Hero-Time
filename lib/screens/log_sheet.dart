import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../sfx.dart';
import '../theme.dart';

/// Log (or edit) one habit for one day: status, quick tags and a note.
Future<void> showLogSheet(BuildContext context, Habit habit, int day) {
  final existing = StoreScope.read(context).entry(habit.id, day);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cardHi,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => LogSheet(habit: habit, day: day, existing: existing),
  );
}

class LogSheet extends StatefulWidget {
  const LogSheet({super.key, required this.habit, required this.day, this.existing});
  final Habit habit;
  final int day;
  final Entry? existing;

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  late int _day = widget.day;
  late Entry? _existing = widget.existing;
  late bool _done = _existing?.done ?? true;
  late final Set<String> _tags = {...?_existing?.tags};
  late final TextEditingController _note = TextEditingController(text: _existing?.note ?? '');

  /// Switch the sheet to another day and load what's logged there.
  void _goTo(int day) {
    if (day > todayKey()) return;
    final e = StoreScope.read(context).entry(widget.habit.id, day);
    setState(() {
      _day = day;
      _existing = e;
      _done = e?.done ?? true;
      _tags
        ..clear()
        ..addAll(e?.tags ?? const []);
      _note.text = e?.note ?? '';
    });
  }

  Future<void> _pickDate() async {
    final now = dayDate(todayKey());
    final picked = await showDatePicker(
      context: context,
      initialDate: dayDate(_day),
      firstDate: DateTime.utc(now.year - 3),
      lastDate: now,
      helpText: 'Log which day?',
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: Theme.of(c).colorScheme.copyWith(
                primary: Color(widget.habit.color),
                onPrimary: const Color(0xFF0B0B0F),
                surface: AppColors.cardHi,
                onSurface: AppColors.text,
              ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.cardHi),
        ),
        child: child!,
      ),
    );
    if (picked != null) _goTo(dayKey(picked));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save(AppStore s) {
    final h = widget.habit;
    final ordered = [
      ...h.tags.where(_tags.contains),
      ..._tags.where((t) => !h.tags.contains(t)),
    ];
    Sfx.play(_done ? 'pop' : 'slip');
    s.setEntry(Entry(habitId: h.id, day: _day, done: _done, note: _note.text.trim(), tags: ordered));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final h = widget.habit;
    final color = Color(h.color);
    final isToday = _day == todayKey();
    final allTags = [...h.tags, ..._tags.where((t) => !h.tags.contains(t))];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(h.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.name, style: heading(21)),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DateBar(
              label: '${fmtDay(_day)}${isToday ? ' · Today' : ''}',
              color: color,
              onPrev: () => _goTo(_day - 1),
              onNext: isToday ? null : () => _goTo(_day + 1),
              onPick: _pickDate,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: h.doneLabel,
                    icon: h.isQuit ? Icons.shield_outlined : Icons.check_rounded,
                    selected: _done,
                    color: color,
                    onTap: () {
                      Sfx.play('check');
                      setState(() => _done = true);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusButton(
                    label: h.missLabel,
                    icon: Icons.close_rounded,
                    selected: !_done,
                    color: AppColors.danger,
                    onTap: () {
                      Sfx.play('slip');
                      setState(() => _done = false);
                    },
                  ),
                ),
              ],
            ),
            if (allTags.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('TAGS', style: ui(11, weight: FontWeight.w700, color: AppColors.muted, spacing: 1.4)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in allTags)
                    TagPill(
                      label: t,
                      selected: _tags.contains(t),
                      color: color,
                      onTap: () {
                        final on = !_tags.contains(t);
                        Sfx.play(on ? 'pop' : 'undo');
                        setState(() => on ? _tags.add(t) : _tags.remove(t));
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 6,
              style: ui(15, height: 1.4),
              textCapitalization: TextCapitalization.sentences,
              decoration: fieldDeco(hint: h.isQuit ? 'How did it go? (optional)' : 'Notes — what did you do? (optional)'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_existing != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: TextButton(
                      onPressed: () {
                        Sfx.play('undo');
                        s.clearEntry(h.id, _day);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(minimumSize: const Size(64, 52)),
                      child: Text('Clear', style: ui(15, color: AppColors.muted)),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _save(s),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: const Color(0xFF0B0B0F),
                      minimumSize: const Size(64, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Save', style: ui(15.5, weight: FontWeight.w700, color: const Color(0xFF0B0B0F))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({required this.label, required this.color, required this.onPrev, required this.onNext, required this.onPick});
  final String label;
  final Color color;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData i, VoidCallback? f, String tip) => IconButton(
          tooltip: tip,
          onPressed: f,
          icon: Icon(i, color: f == null ? AppColors.faint.withValues(alpha: 0.4) : AppColors.text),
        );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, onPrev, 'Previous day'),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: color),
                    const SizedBox(width: 8),
                    Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: ui(14.5, weight: FontWeight.w600))),
                  ],
                ),
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, onNext, 'Next day'),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 56,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : AppColors.cardHi,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color.withValues(alpha: 0.8) : AppColors.border, width: 1.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? color : AppColors.muted),
            const SizedBox(width: 8),
            Text(label, style: ui(15, weight: FontWeight.w600, color: selected ? AppColors.text : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill({super.key, required this.label, required this.selected, required this.color, this.onTap, this.small = false});
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: small ? 9 : 14, vertical: small ? 4 : 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : AppColors.cardHi,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? color.withValues(alpha: 0.7) : AppColors.border),
        ),
        child: Text(
          label,
          style: ui(small ? 11.5 : 13.5, weight: FontWeight.w600, color: selected ? AppColors.text : AppColors.muted),
        ),
      ),
    );
  }
}
