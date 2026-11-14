import 'dart:convert';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';
import 'sfx.dart';
import 'stats.dart';
import 'widgets/character.dart';

/// Single source of truth. Everything is persisted locally as JSON.
class AppStore extends ChangeNotifier {
  static const _kHabits = 'habits_v1';
  static const _kEntries = 'entries_v1';
  static const _kSettings = 'settings_v1';
  static const _kHeroes = 'heroes_v1'; // custom heroes; photos under 'hero_img_<id>'
  static const _kTracks = 'tracks_v1'; // lobby music library (files stay on the phone)

  /// Lobby music tracks added from this phone. Not part of backups.
  List<Track> tracks = [];

  /// Bundled tracks first, then the ones added from this phone.
  List<Track> get allTracks => [...builtInTracks, ...tracks];

  /// The chosen lobby track; the classic instrumental until you pick another.
  Track get selectedTrack {
    for (final t in allTracks) {
      if (t.id == settings.musicTrack) return t;
    }
    return builtInTracks.first;
  }

  late SharedPreferences _prefs;
  List<Habit> habits = [];
  final Map<String, Entry> _entries = {};
  Settings settings = Settings();

  /// Called when the level rises after a change (old, new). Set by the app shell.
  void Function(int from, int to)? onLevelUp;
  int? _lastLevel;

  static String _key(String habitId, int day) => '$habitId|$day';

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final h = _prefs.getString(_kHabits);
    if (h == null) {
      habits = defaultHabits();
      await _write();
    } else {
      habits = (jsonDecode(h) as List).map((e) => Habit.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    final e = _prefs.getString(_kEntries);
    if (e != null) {
      for (final x in jsonDecode(e) as List) {
        final en = Entry.fromJson(Map<String, dynamic>.from(x as Map));
        _entries[_key(en.habitId, en.day)] = en;
      }
    }
    final hj = _prefs.getString(_kHeroes);
    if (hj != null) {
      setCustomHeroes([
        for (final x in jsonDecode(hj) as List)
          Alien.fromJson(Map<String, dynamic>.from(x as Map),
              Alien.decodePhoto(_prefs.getString('hero_img_${x['id']}'))),
      ]);
    }
    final tj = _prefs.getString(_kTracks);
    if (tj != null) {
      tracks = [for (final x in jsonDecode(tj) as List) Track.fromJson(Map<String, dynamic>.from(x as Map))];
    }
    final s = _prefs.getString(_kSettings);
    if (s != null) settings = Settings.fromJson(Map<String, dynamic>.from(jsonDecode(s) as Map));
    Sfx.enabled = settings.sound;
    _lastLevel = progressOf(this).level;
  }

  // ---------- reads ----------

  Habit? habitById(String id) {
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Entry? entry(String habitId, int day) => _entries[_key(habitId, day)];
  bool isDone(String habitId, int day) => _entries[_key(habitId, day)]?.done ?? false;
  Iterable<Entry> entriesFor(String habitId) => _entries.values.where((e) => e.habitId == habitId);
  Set<int> doneDays(String habitId) => {
        for (final e in _entries.values)
          if (e.habitId == habitId && e.done) e.day
      };

  bool get allLoggedToday {
    final t = todayKey();
    return habits.isNotEmpty && habits.every((h) => entry(h.id, t) != null);
  }

  List<Habit> get pendingToday {
    final t = todayKey();
    return habits.where((h) => entry(h.id, t) == null).toList();
  }

  // ---------- writes ----------

  void setEntry(Entry e) {
    _entries[_key(e.habitId, e.day)] = e;
    _save();
  }

  void clearEntry(String habitId, int day) {
    _entries.remove(_key(habitId, day));
    _save();
  }

  /// Tick (done = true) or cross (done = false) a day. Tapping the answer that's
  /// already set clears the day, unless it has a note or tags (those are kept and
  /// the day stays as it is; the log sheet's Clear button removes them).
  /// Returns the day's state afterwards: true done, false missed, null unlogged.
  bool? mark(Habit h, int day, bool done) {
    final cur = entry(h.id, day);
    if (cur == null) {
      setEntry(Entry(habitId: h.id, day: day, done: done));
      return done;
    }
    if (cur.done != done) {
      cur.done = done;
      _save();
      return done;
    }
    if (cur.hasDetails) return done;
    clearEntry(h.id, day);
    return null;
  }

  void upsertHabit(Habit h) {
    final i = habits.indexWhere((x) => x.id == h.id);
    if (i >= 0) {
      habits[i] = h;
    } else {
      habits.add(h);
    }
    _save();
  }

  void deleteHabit(String id) {
    habits.removeWhere((h) => h.id == id);
    _entries.removeWhere((k, e) => e.habitId == id);
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final h = habits.removeAt(oldIndex);
    habits.insert(newIndex, h);
    _save();
  }

  void updateSettings(void Function(Settings s) change) {
    change(settings);
    _save();
  }

  /// Called when the app comes back to the foreground (date may have changed).
  void refresh() {
    notifyListeners();
    Reminders.reschedule(this);
  }

  // ---------- custom heroes (stay on this phone, never in backups) ----------

  /// Adds or updates a custom hero. Pass [photo] only when it changed.
  Future<void> saveHero(Alien hero, {Uint8List? photo}) async {
    if (photo != null) {
      await _prefs.setString('hero_img_${hero.id}', base64Encode(photo));
      hero = hero.copyWith(photo: photo);
    }
    final list = customHeroes;
    final i = list.indexOf(hero);
    i >= 0 ? list[i] = hero : list.add(hero);
    await _writeHeroes(list);
  }

  Future<void> deleteHero(Alien hero) async {
    await _prefs.remove('hero_img_${hero.id}');
    await _writeHeroes(customHeroes..remove(hero));
    if (settings.alien == hero.id) {
      updateSettings((x) => x.alien = builtInAliens.first.id);
    }
  }

  Future<void> _writeHeroes(List<Alien> list) async {
    setCustomHeroes(list);
    await _prefs.setString(_kHeroes, jsonEncode(list.map((h) => h.toJson()).toList()));
    notifyListeners();
  }

  // ---------- lobby music library ----------

  Future<void> saveTracks() async {
    await _prefs.setString(_kTracks, jsonEncode(tracks.map((t) => t.toJson()).toList()));
    notifyListeners();
  }

  Future<void> addTrack(Track t) async {
    tracks.add(t);
    await saveTracks();
    updateSettings((x) => x.musicTrack = t.id); // a new track starts playing right away
  }

  Future<void> removeTrack(Track t) async {
    tracks.removeWhere((x) => x.id == t.id);
    await saveTracks();
    if (!kIsWeb) {
      try {
        final f = File(t.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    if (settings.musicTrack == t.id) {
      updateSettings((x) => x.musicTrack = null); // back to the default
    }
  }

  // ---------- backup ----------

  String exportJson() => const JsonEncoder.withIndent(' ').convert({
        'app': 'ember',
        'v': 1,
        'habits': habits.map((h) => h.toJson()).toList(),
        'entries': _entries.values.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      });

  bool importJson(String raw) {
    try {
      final j = Map<String, dynamic>.from(jsonDecode(raw.trim()) as Map);
      final hs = (j['habits'] as List).map((e) => Habit.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final es = (j['entries'] as List).map((e) => Entry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      habits = hs;
      _entries
        ..clear()
        ..addEntries(es.map((e) => MapEntry(_key(e.habitId, e.day), e)));
      if (j['settings'] is Map) settings = Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map));
      _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  void resetAll() {
    habits = defaultHabits();
    _entries.clear();
    settings = Settings();
    _save();
  }

  // ---------- persistence ----------

  Future<void> _write() async {
    await _prefs.setString(_kHabits, jsonEncode(habits.map((h) => h.toJson()).toList()));
    await _prefs.setString(_kEntries, jsonEncode(_entries.values.map((e) => e.toJson()).toList()));
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  void _save() {
    Sfx.enabled = settings.sound;
    final lv = progressOf(this).level;
    final prev = _lastLevel;
    _lastLevel = lv;
    if (prev != null && lv > prev) onLevelUp?.call(prev, lv);
    notifyListeners();
    _write();
    Reminders.reschedule(this);
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  /// Use in build methods (rebuilds on change).
  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Use in callbacks / initState (no rebuild dependency).
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
