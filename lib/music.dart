import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'store.dart';

/// Lobby music: the track chosen in Settings loops quietly while the app is open.
/// Tracks are bundled with the app or added from the phone (kept in the app's storage).
class Music {
  static const _volume = 0.32;
  static const _ducked = 0.05;

  static final AudioPlayer _p = AudioPlayer(playerId: 'music');
  static bool _setUp = false;
  static String? _loaded; // what's in the player now
  static bool _want = false; // music switched on and a theme chosen
  static bool _foreground = true;
  static bool _playing = false;
  static double _level = 0;
  static Timer? _fade;
  static Timer? _duckEnd;
  static bool _isDucked = false;

  static Future<void> _ensureSetUp() async {
    if (_setUp) return;
    _setUp = true;
    await _p.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
    await _p.setReleaseMode(ReleaseMode.loop);
    await _p.setVolume(0);
  }

  // Changes run one at a time, so a quick pause/resume can't interleave.
  static Future<void> _queue = Future.value();
  static Future<void> _serial(Future<void> Function() f) =>
      _queue = _queue.then((_) => f()).catchError((Object e) => debugPrint('Music: $e'));

  /// Match the music to the store: on/off and which track is chosen.
  static Future<void> sync(AppStore s) => _serial(() => _sync(s));

  static Future<void> _sync(AppStore s) async {
    final t = s.selectedTrack;
    final key = t.asset ?? t.path;
    _want = s.settings.music;
    try {
      await _ensureSetUp();
      if (_want && key != _loaded) {
        await _fadeTo(0, 350);
        _loaded = key;
        await _p.setSource(t.builtIn ? AssetSource(key) : DeviceFileSource(key));
        _playing = false;
      }
      await _apply();
    } catch (e) {
      debugPrint('Music.sync failed: $e');
      _loaded = null;
    }
  }

  /// The app went to the background (false) or came back (true).
  static Future<void> setForeground(bool fg) {
    _foreground = fg;
    return _serial(_apply);
  }

  /// Drop the music under a big sound effect (the transform theme), then bring it back.
  static void duck(Duration d) {
    if (!_playing) return;
    _isDucked = true;
    _fadeTo(_ducked, 150);
    _duckEnd?.cancel();
    _duckEnd = Timer(d, () {
      _isDucked = false;
      if (_playing) _fadeTo(_volume, 900);
    });
  }

  static Future<void> _apply() async {
    final should = _want && _foreground && _loaded != null;
    if (should && !_playing) {
      await _p.resume(); // may throw (e.g. browser autoplay rules); the next sync retries
      _playing = true;
      await _fadeTo(_isDucked ? _ducked : _volume, 900);
    } else if (!should && _playing) {
      _playing = false;
      await _fadeTo(0, 300);
      await _p.pause();
    }
  }

  static Completer<void>? _fadeDone;

  static Future<void> _fadeTo(double target, int ms) {
    _fade?.cancel();
    if (_fadeDone?.isCompleted == false) _fadeDone!.complete(); // a newer fade takes over
    final done = _fadeDone = Completer<void>();
    final from = _level;
    const stepMs = 30;
    final steps = (ms / stepMs).ceil().clamp(1, 1000);
    var i = 0;
    _fade = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      i++;
      _level = from + (target - from) * (i / steps);
      _p.setVolume(_level).catchError((_) {});
      if (i >= steps) {
        t.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    return done.future;
  }
}
