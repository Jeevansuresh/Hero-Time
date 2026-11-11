import 'package:flutter/material.dart';

import '../models.dart';
import '../stats.dart';
import '../store.dart';
import '../sfx.dart';
import '../theme.dart';

const _quickEmojis = [
  '🏋️', '🏃', '🧘', '💧', '🥗', '🍬', '🌙', '📚', '✍️', '📵', '🚭', '🍺', '☕', '🎮', '🧠', '🦷', '🌅', '💸',
];

class HabitEditorScreen extends StatefulWidget {
  const HabitEditorScreen({super.key, this.habit});
  final Habit? habit;

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  late final Habit _h = widget.habit?.copy() ??
      Habit(
        id: newId(),
        name: '',
        emoji: '✨',
        kind: HabitKind.build,
        target: 7,
        color: habitPalette[0],
        tags: [],
        createdDay: todayKey(),
      );
  late final TextEditingController _name = TextEditingController(text: _h.name);
  late final TextEditingController _emoji = TextEditingController(text: _h.emoji);
  final TextEditingController _tag = TextEditingController();

  bool get _isNew => widget.habit == null;

  @override
  void dispose() {
    _name.dispose();
    _emoji.dispose();
    _tag.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the mission a name')));
      return;
    }
    _h.name = name;
    final e = _emoji.text.trim();
    _h.emoji = e.isEmpty ? '✨' : e;
    _addTag(_tag.text);
    Sfx.play('pop');
    StoreScope.read(context).upsertHabit(_h);
    Navigator.pop(context);
  }

  void _addTag(String raw) {
    final t = raw.trim();
    if (t.isNotEmpty && !_h.tags.contains(t)) setState(() => _h.tags.add(t));
    _tag.clear();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete ${_h.name}?',
      body: 'Its whole history goes with it, along with the XP it earned.',
    );
    if (!ok || !mounted) return;
    Sfx.play('slip');
    StoreScope.read(context).deleteHabit(_h.id);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final level = progressOf(s).level;
    final unlockAll = s.settings.unlockAll;
    final color = Color(_h.color);

    return AppScaffold(
      appBar: flatAppBar(_isNew ? 'New mission' : 'Edit mission', actions: [
        TextButton(
          onPressed: _save,
          child: Text('Save', style: ui(15, weight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 8),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          Row(
            children: [
              SizedBox(
                width: 66,
                child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26),
                  decoration: fieldDeco().copyWith(fillColor: color.withValues(alpha: 0.14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: _isNew,
                  textCapitalization: TextCapitalization.sentences,
                  style: ui(16.5, weight: FontWeight.w600),
                  decoration: fieldDeco(hint: 'Mission name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in _quickEmojis)
                  GestureDetector(
                    onTap: () => setState(() => _emoji.text = e),
                    child: Container(
                      width: 42,
                      alignment: Alignment.center,
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
          ),
          const SectionLabel('Type'),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  title: 'Build',
                  subtitle: 'Something to do',
                  icon: Icons.trending_up_rounded,
                  selected: _h.kind == HabitKind.build,
                  color: color,
                  onTap: () => setState(() => _h.kind = HabitKind.build),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ChoiceTile(
                  title: 'Quit',
                  subtitle: 'Something to avoid',
                  icon: Icons.block_rounded,
                  selected: _h.kind == HabitKind.quit,
                  color: color,
                  onTap: () => setState(() => _h.kind = HabitKind.quit),
                ),
              ),
            ],
          ),
          SectionLabel(
            'Weekly goal',
            trailing: Text(
              _h.target == 7 ? 'Every day' : '${_h.target} days / week',
              style: ui(12.5, weight: FontWeight.w600, color: color),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 7; i++)
                GestureDetector(
                  onTap: () => setState(() => _h.target = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= _h.target ? color.withValues(alpha: i == _h.target ? 1.0 : 0.22) : AppColors.cardHi,
                    ),
                    child: Text(
                      '$i',
                      style: ui(15,
                          weight: FontWeight.w700,
                          color: i == _h.target ? const Color(0xFF0B0B0F) : AppColors.text),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _h.isQuit
                ? (_h.target == 7
                    ? 'Zero slips allowed. Streak counts in days.'
                    : '${7 - _h.target} slip day${7 - _h.target == 1 ? '' : 's'} a week allowed. Streak counts in weeks.')
                : (_h.target == 7
                    ? 'Daily habit. Streak counts in days.'
                    : 'Rest days never break it. Streak counts weeks where you hit ${_h.target}.'),
            style: ui(12.5, color: AppColors.muted, height: 1.4),
          ),
          const SectionLabel('Colour'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < habitPalette.length; i++)
                _Swatch(
                  color: Color(habitPalette[i]),
                  selected: _h.color == habitPalette[i],
                  lockedUntil: (!unlockAll && level < paletteUnlockLevel[i]) ? paletteUnlockLevel[i] : null,
                  onTap: () {
                    if (!unlockAll && level < paletteUnlockLevel[i]) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text('Unlocks at Lv ${paletteUnlockLevel[i]}')));
                      return;
                    }
                    setState(() => _h.color = habitPalette[i]);
                  },
                ),
            ],
          ),
          SectionLabel('Quick tags', trailing: Text('shown when logging', style: ui(11, color: AppColors.faint))),
          if (_h.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in _h.tags)
                    InputChip(
                      label: Text(t, style: ui(13)),
                      backgroundColor: AppColors.cardHi,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      onDeleted: () => setState(() => _h.tags.remove(t)),
                    ),
                ],
              ),
            ),
          TextField(
            controller: _tag,
            style: ui(15),
            textCapitalization: TextCapitalization.sentences,
            decoration: fieldDeco(hint: _h.tags.isEmpty ? 'e.g. Chest, Legs, Cardio…' : 'Add a tag').copyWith(
              suffixIcon: IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _addTag(_tag.text)),
            ),
            onSubmitted: _addTag,
          ),
          if (!_isNew) ...[
            const SizedBox(height: 36),
            Center(
              child: TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                label: Text('Delete mission', style: ui(14.5, color: AppColors.danger)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color.withValues(alpha: 0.75) : AppColors.border, width: 1.3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? color : AppColors.muted, size: 22),
            const SizedBox(height: 10),
            Text(title, style: ui(15, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: ui(12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap, this.lockedUntil});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final int? lockedUntil;

  @override
  Widget build(BuildContext context) {
    final locked = lockedUntil != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.text : Colors.transparent, width: 2),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: locked ? color.withValues(alpha: 0.18) : color,
          ),
          child: locked ? Icon(Icons.lock_rounded, size: 14, color: color.withValues(alpha: 0.9)) : null,
        ),
      ),
    );
  }
}
