import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../sfx.dart';
import '../store.dart';
import '../theme.dart';

/// Settings → Lobby music: switch it on or off, add tracks from the phone, pick one.
/// Tracks are copied into the app's own storage; they never leave the phone.
class LobbyMusicScreen extends StatefulWidget {
  const LobbyMusicScreen({super.key});

  @override
  State<LobbyMusicScreen> createState() => _LobbyMusicScreenState();
}

class _LobbyMusicScreenState extends State<LobbyMusicScreen> {
  bool _adding = false;

  static String _title(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  Future<void> _add() async {
    final s = StoreScope.read(context);
    final msg = ScaffoldMessenger.of(context);
    final f = await FilePicker.pickFile(type: FileType.audio);
    if (f == null) return;
    setState(() => _adding = true);
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/music');
      await dir.create(recursive: true);
      final id = 'track_${DateTime.now().millisecondsSinceEpoch}';
      final ext = f.extension ?? 'mp3';
      final out = File('${dir.path}/$id.$ext');
      final sink = out.openWrite();
      await sink.addStream(f.readAsByteStream());
      await sink.close();
      await s.addTrack(Track(id: id, name: _title(f.name), path: out.path));
      Sfx.play('pop');
    } catch (e) {
      msg
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't add that file")));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _rename(AppStore s, Track t) async {
    final n = await promptText(context, title: 'Track name', initial: t.name);
    if (n == null || n.trim().isEmpty) return;
    t.name = n.trim();
    await s.saveTracks();
  }

  Future<void> _remove(AppStore s, Track t) async {
    final ok = await confirm(context, title: 'Remove "${t.name}"?', body: 'The copy in Hero Time is deleted from this phone.',
        action: 'Remove');
    if (ok) await s.removeTrack(t);
  }

  Widget _row(AppStore s, Track t) {
    final st = s.settings;
    final on = t.id == s.selectedTrack.id;
    return InkWell(
      onTap: () => s.updateSettings((x) {
        x.musicTrack = t.id;
        x.music = true;
      }),
      onLongPress: t.builtIn ? null : () => _rename(s, t),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, t.builtIn ? 16 : 6, 12),
        child: Row(
          children: [
            Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: on ? AppColors.green : AppColors.faint, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(14.5, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    on ? (st.music ? 'Now playing' : 'Selected · music is off') : (t.builtIn ? 'Built in' : 'From your phone'),
                    style: ui(11.5, color: on && st.music ? AppColors.green : AppColors.muted),
                  ),
                ],
              ),
            ),
            if (!t.builtIn)
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.muted),
                onPressed: () => _remove(s, t),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final st = s.settings;
    return AppScaffold(
      appBar: flatAppBar('Lobby music'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 48),
        children: [
          Panel(
            padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Play lobby music', style: ui(15, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Loops quietly while the app is open', style: ui(12.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                Switch(
                  value: st.music,
                  activeTrackColor: AppColors.green,
                  onChanged: (v) => s.updateSettings((x) => x.music = v),
                ),
              ],
            ),
          ),
          const SectionLabel('Tracks'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [for (final t in s.allTracks) _row(s, t)],
            ),
          ),
          if (s.tracks.isEmpty) ...[
            const SizedBox(height: 10),
            Text('Add your own: save a song to your phone, then add it below. It stays on this phone.',
                textAlign: TextAlign.center, style: ui(12, color: AppColors.faint, height: 1.4)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: kIsWeb || _adding ? null : _add,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              foregroundColor: const Color(0xFF0B0B0F),
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: _adding
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.library_music_rounded),
            label: Text(kIsWeb ? 'Adding tracks works in the phone app' : 'Add track from phone',
                style: ui(15, weight: FontWeight.w700, color: const Color(0xFF0B0B0F))),
          ),
          const SizedBox(height: 10),
          Text('Tap a track to play it. Long-press one of yours to rename it.',
              textAlign: TextAlign.center, style: ui(12, color: AppColors.faint)),
        ],
      ),
    );
  }
}
