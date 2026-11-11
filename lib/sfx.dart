import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short synthesised sound effects bundled in assets/sfx.
class Sfx {
  static bool enabled = true;
  static final List<AudioPlayer> _pool = [];
  static int _next = 0;

  /// Recorded clips that replace a synthesised effect.
  static const _clips = {'transform': 'sfx/transform_theme.mp3'};

  static Future<void> play(String name) async {
    if (!enabled) return;
    try {
      if (_pool.isEmpty) {
        for (var i = 0; i < 4; i++) {
          _pool.add(AudioPlayer());
        }
      }
      final p = _pool[_next++ % _pool.length];
      await p.stop();
      final clip = _clips[name];
      await p.play(
        AssetSource(clip ?? 'sfx/$name.wav'),
        mode: clip != null ? PlayerMode.mediaPlayer : PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Sfx.play($name) failed: $e');
    }
  }
}
