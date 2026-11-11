import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';
import 'sfx.dart';
import 'stats.dart';

/// Single source of truth. Everything is persisted locally as JSON.
class AppStore extends ChangeNotifier {
  static const _kHabits = 'habits_v1';
  static const _kEntries = 'entries_v1';
  static const _kSettings = 'settings_v1';

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

  /// Quick tap on the check button. Returns true if the habit is now done.
  bool toggleToday(Habit h) {
    final t = todayKey();
    final cur = entry(h.id, t);
    if (cur == null) {
      setEntry(Entry(habitId: h.id, day: t, done: true));
      return true;
    }
    if (!cur.done) {
      cur.done = true;
      _save();
      return true;
    }
    if (cur.hasDetails) {
      cur.done = false;
      _save();
    } else {
      clearEntry(h.id, t);
    }
    return false;
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
