import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../sfx.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/character.dart';

/// Add or edit a custom hero: your own photo, name and colour.
/// The photo is kept in the app's storage on this phone only.
class HeroEditorScreen extends StatefulWidget {
  const HeroEditorScreen({super.key, this.hero});
  final Alien? hero;

  @override
  State<HeroEditorScreen> createState() => _HeroEditorScreenState();
}

class _HeroEditorScreenState extends State<HeroEditorScreen> {
  late final _name = TextEditingController(text: widget.hero?.name ?? '');
  late final _species = TextEditingController(text: widget.hero?.species ?? 'Human');
  late final _blurb = TextEditingController(text: widget.hero?.blurb ?? '');
  late Color _color = widget.hero?.color ?? const Color(0xFFC0D72D);
  Uint8List? _photo; // newly picked photo, if any
  bool _busy = false;

  Uint8List? get _shown => _photo ?? widget.hero?.photo;

  @override
  void dispose() {
    _name.dispose();
    _species.dispose();
    _blurb.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 768,
      maxHeight: 768,
      requestFullMetadata: false,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final msg = ScaffoldMessenger.of(context);
    if (name.isEmpty || _shown == null) {
      msg
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(name.isEmpty ? 'Give your hero a name' : 'Pick a photo for your hero')));
      return;
    }
    setState(() => _busy = true);
    final s = StoreScope.read(context);
    final base = widget.hero ??
        Alien('$customHeroPrefix${DateTime.now().millisecondsSinceEpoch}', name, 'Human', 1, _color, '');
    final species = _species.text.trim();
    final hero = Alien(base.id, name, species.isEmpty ? 'Human' : species, 1, _color, _blurb.text.trim(),
        photo: base.photo);
    await s.saveHero(hero, photo: _photo);
    Sfx.play('goal');
    if (!mounted) return;
    Navigator.pop(context);
    msg
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(widget.hero == null ? '$name added to the Omnitrix' : '$name updated')));
  }

  Future<void> _delete() async {
    final h = widget.hero!;
    final ok = await confirm(context,
        title: 'Remove ${h.name}?', body: 'Their photo is deleted from this phone. Your missions and XP are not affected.');
    if (!ok || !mounted) return;
    await StoreScope.read(context).deleteHero(h);
    Sfx.play('undo');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.hero != null;
    final shown = _shown;
    return AppScaffold(
      appBar: flatAppBar(editing ? 'Edit hero' : 'New hero', actions: [
        if (editing) IconButton(tooltip: 'Remove hero', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pick,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                  border: Border.all(color: _color.withValues(alpha: 0.7), width: 2),
                  boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.3), blurRadius: 30)],
                ),
                child: shown == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: _color),
                          const SizedBox(height: 8),
                          Text('Pick a photo', style: ui(14, weight: FontWeight.w600)),
                        ],
                      )
                    : Padding(
                        padding: const EdgeInsets.all(14),
                        child: Image.memory(shown, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
          if (shown != null)
            Center(
              child: TextButton.icon(
                onPressed: _pick,
                icon: Icon(Icons.photo_library_outlined, size: 18, color: _color),
                label: Text('Change photo', style: ui(13.5, weight: FontWeight.w600, color: _color)),
              ),
            ),
          const SizedBox(height: 6),
          Text('A PNG with a transparent background looks best, like the aliens. '
              'The photo stays on this phone and is never uploaded or included in backups.',
              textAlign: TextAlign.center, style: ui(12, color: AppColors.faint, height: 1.45)),
          const SectionLabel('Name'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            style: ui(16),
            decoration: fieldDeco(hint: 'e.g. Jeevan'),
          ),
          const SectionLabel('Species'),
          TextField(
            controller: _species,
            textCapitalization: TextCapitalization.words,
            style: ui(16),
            decoration: fieldDeco(hint: 'Human'),
          ),
          const SectionLabel('Tagline'),
          TextField(
            controller: _blurb,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            style: ui(16),
            decoration: fieldDeco(hint: 'e.g. Never skips leg day.'),
          ),
          const SectionLabel('Colour'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in habitPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = Color(c)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(c),
                      border: Border.all(
                        color: _color.toARGB32() == c ? AppColors.text : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              foregroundColor: const Color(0xFF0B0B0F),
              minimumSize: const Size(64, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(editing ? 'Save hero' : 'Add to the Omnitrix',
                style: ui(15.5, weight: FontWeight.w700, color: const Color(0xFF0B0B0F))),
          ),
        ],
      ),
    );
  }
}
