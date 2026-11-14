import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'music.dart';

/// Sound effects bundled in assets/sfx.
///
/// Each effect gets its own preloaded player in normal media-player mode. (Android's
/// low-latency SoundPool mode silently drops bundled asset sounds on many phones.)
class Sfx {
  static bool enabled = true;

  /// Recorded clips that replace a synthesised effect.
  static const _clips = {
    'transform': 'sfx/transform_theme.mp3',
    'initiate': 'sfx/omnitrix_initiate.mp3',
  };

  static final Map<String, AudioPlayer> _players = {};
  static final _context = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  /// Aliens with a voice line, played right after the transform theme (assets/sfx/voice_<id>.mp3).
  static const voiced = {'diamondhead', 'fourarms', 'swampfire', 'jetray', 'humungousaur', 'waybig', 'alienx'};

  /// The transform theme plays this long, then fades out as the alien's voice line comes in.
  static const _themeLength = Duration(milliseconds: 1600);
  static Timer? _voice;

  static String _path(String name) =>
      _clips[name] ?? (name.startsWith('voice_') ? 'sfx/$name.mp3' : 'sfx/$name.wav');

  /// Transform: the theme first, then the new alien's voice line (if it has one).
  static void transformInto(String alienId) {
    _voice?.cancel(); // a quick re-transform drops the previous alien's line
    play('transform');
    final speaks = voiced.contains(alienId);
    if (speaks) _player('voice_$alienId'); // load it while the theme plays
    _voice = Timer(_themeLength, () {
      _fadeOut('transform');
      if (speaks) play('voice_$alienId');
    });
  }

  /// Quick fade so the cut-off theme doesn't click, then reset for next time.
  static Future<void> _fadeOut(String name) async {
    final p = _players[name];
    if (p == null) return;
    try {
      for (final v in [0.6, 0.3, 0.1]) {
        await p.setVolume(v);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await p.stop();
      await p.setVolume(1);
    } catch (_) {}
  }

  static Future<AudioPlayer> _player(String name) async {
    final existing = _players[name];
    if (existing != null) return existing;
    final p = AudioPlayer(playerId: 'sfx_$name');
    await p.setAudioContext(_context);
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource(_path(name)));
    return _players[name] = p;
  }

  /// Load the common effects up front so the first tap isn't silent.
  static Future<void> warmUp() async {
    for (final n in ['check', 'undo', 'pop', 'goal', 'slip', 'dial']) {
      try {
        await _player(n);
      } catch (e) {
        debugPrint('Sfx.warmUp($n) failed: $e');
      }
    }
  }

  static Future<void> play(String name) async {
    if (!enabled) return;
    if (name == 'transform') Music.duck(const Duration(milliseconds: 1800));
    if (name == 'initiate') Music.duck(const Duration(milliseconds: 1300));
    if (name.startsWith('voice_')) Music.duck(const Duration(milliseconds: 2400));
    try {
      final p = await _player(name);
      await p.stop();
      await p.setVolume(1); // in case a fade-out was cut short
      await p.seek(Duration.zero);
      await p.resume();
    } catch (e) {
      debugPrint('Sfx.play($name) failed: $e');
      _players.remove(name)?.dispose();
    }
  }
}
