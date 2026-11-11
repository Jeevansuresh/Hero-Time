import 'dart:math' as math;

import 'models.dart';
import 'store.dart';

/// First day a habit "counts" from: its creation day, or an earlier backfilled log.
int startDayOf(Habit h, Set<int> done) {
  var s = h.createdDay;
  for (final d in done) {
    if (d < s) s = d;
  }
  return s;
}

int _weekCount(Set<int> done, int weekStart) {
  var c = 0;
  for (var i = 0; i < 7; i++) {
    if (done.contains(weekStart + i)) c++;
  }
  return c;
}

class HabitStats {
  const HabitStats({
    required this.streak,
    required this.best,
    required this.weekly,
    required this.weekDone,
    required this.total,
    required this.score,
  });

  /// Daily habits (7/7) count streaks in days; lighter goals (e.g. gym 4/7) count
  /// consecutive weeks where the goal was hit — a rest day never breaks it.
  final int streak;
  final int best;
  final bool weekly;
  final int weekDone;
  final int total;

  /// 0–100, adherence over the last 4 weeks. Null until there is data.
  final int? score;

  String get unitShort => weekly ? 'w' : 'd';
  String get unitLong => weekly ? (streak == 1 ? 'week' : 'weeks') : (streak == 1 ? 'day' : 'days');
}

HabitStats statsFor(Habit h, Set<int> done, [int? todayArg]) {
  final today = todayArg ?? todayKey();
  final start = startDayOf(h, done);
  final thisWeek = weekStartOf(today);
  final weekDone = _weekCount(done, thisWeek);
  final weekly = h.target < 7;
  var streak = 0, best = 0;

  if (!weekly) {
    var d = done.contains(today) ? today : today - 1; // today isn't over yet
    while (done.contains(d)) {
      streak++;
      d--;
    }
    final sorted = done.toList()..sort();
    var run = 0;
    int? prev;
    for (final x in sorted) {
      run = (prev != null && x == prev + 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = x;
    }
  } else {
    final firstWeek = weekStartOf(start);
    // The current week only counts once the goal is reached; it can't break the streak yet.
    var w = weekDone >= h.target ? thisWeek : thisWeek - 7;
    while (w >= firstWeek && _weekCount(done, w) >= h.target) {
      streak++;
      w -= 7;
    }
    var run = 0;
    for (var s = firstWeek; s <= thisWeek; s += 7) {
      if (_weekCount(done, s) >= h.target) {
        run++;
        if (run > best) best = run;
      } else if (s != thisWeek) {
        run = 0;
      }
    }
  }
  if (streak > best) best = streak;

  // Score: four rolling 7-day windows, each = min(successes / target, 1).
  final ref = done.contains(today) ? today : today - 1;
  var sum = 0.0;
  var n = 0;
  for (var k = 0; k < 4; k++) {
    final end = ref - 7 * k;
    if (end < start) break;
    final from = end - 6;
    final firstCounted = from > start ? from : start;
    final avail = end - firstCounted + 1;
    var c = 0;
    for (var d = firstCounted; d <= end; d++) {
      if (done.contains(d)) c++;
    }
    final tgt = math.max(1.0, h.target * avail / 7.0);
    sum += math.min(1.0, c / tgt);
    n++;
  }

  return HabitStats(
    streak: streak,
    best: best,
    weekly: weekly,
    weekDone: weekDone,
    total: done.length,
    score: n == 0 ? null : (sum / n * 100).round(),
  );
}

/// Per-frame snapshot so heatmaps don't recompute sets per cell.
class Snapshot {
  Snapshot(this.store) : today = todayKey() {
    for (final h in store.habits) {
      final d = store.doneDays(h.id);
      done[h.id] = d;
      starts[h.id] = startDayOf(h, d);
    }
  }

  final AppStore store;
  final int today;
  final Map<String, Set<int>> done = {};
  final Map<String, int> starts = {};

  /// Fraction of habits completed on [day] (only habits that existed then). -1 = none existed.
  double intensity(int day) {
    var active = 0, c = 0;
    for (final h in store.habits) {
      if (day < starts[h.id]!) continue;
      active++;
      if (done[h.id]!.contains(day)) c++;
    }
    return active == 0 ? -1 : c / active;
  }

  int? get overallScore {
    final scores = [
      for (final h in store.habits) statsFor(h, done[h.id]!, today).score,
    ].whereType<int>().toList();
    if (scores.isEmpty) return null;
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  int get doneToday => store.habits.where((h) => done[h.id]!.contains(today)).length;
}

// ---------- Companion progression (aliens live in widgets/character.dart) ----------

/// Levels at which an extra habit slot unlocks (4 slots to start).
const slotLevels = [2, 4, 7, 10, 15];
const baseSlots = 5;

int habitSlots(int level, bool unlockAll) =>
    unlockAll ? 99 : baseSlots + slotLevels.where((l) => level >= l).length;

int? nextSlotLevel(int level) {
  for (final l in slotLevels) {
    if (l > level) return l;
  }
  return null;
}

/// Cumulative XP needed to reach [level]: 0, 100, 300, 600, 1000, …
int xpThreshold(int level) => 50 * (level - 1) * level;

const xpPerDay = 10;
const xpPerDetail = 3;
const xpPerWeekGoal = 40;

class Progress {
  const Progress(this.xp, this.level);
  final int xp;
  final int level;
  int get floor => xpThreshold(level);
  int get next => xpThreshold(level + 1);
  double get fraction => (xp - floor) / (next - floor);
}

/// XP is derived from the log every time, so editing history keeps it honest.
Progress progressOf(AppStore s) {
  final today = todayKey();
  var xp = 0;
  for (final h in s.habits) {
    final done = s.doneDays(h.id);
    if (done.isEmpty) continue;
    for (final d in done) {
      xp += xpPerDay;
      if (s.entry(h.id, d)?.hasDetails ?? false) xp += xpPerDetail;
    }
    final start = startDayOf(h, done);
    for (var w = weekStartOf(start); w <= weekStartOf(today); w += 7) {
      if (_weekCount(done, w) >= h.target) xp += xpPerWeekGoal;
    }
  }
  var level = 1;
  while (xp >= xpThreshold(level + 1)) {
    level++;
  }
  return Progress(xp, level);
}
