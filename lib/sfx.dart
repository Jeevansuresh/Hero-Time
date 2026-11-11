import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short synthesised sound effects bundled in assets/sfx.
class Sfx {
  static bool enabled = true;
  static final List<AudioPlayer> _pool = [];
  static int _next = 0;

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
      await p.play(AssetSource('sfx/$name.wav'), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Sfx.play($name) failed: $e');
    }
  }
}
