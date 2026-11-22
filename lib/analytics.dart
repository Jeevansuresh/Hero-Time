import 'dart:math' as math;

import 'models.dart';
import 'store.dart';

/// Everything Analytics and Insights show, worked out from the ✓ / ✕ log on the phone.
/// Only uses what the app stores: done or missed per day, notes on misses, and tags.

const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class MissionStats {
  MissionStats(this.h);
  final Habit h;

  /// Successes per week: last 2 weeks, and the 6 weeks before that (your "usual").
  double recent = 0;
  double? usual;
  int? sinceLast; // days since the last ✓ (0 = today)
  int bestRun = 0; // longest run of consecutive ✓ days
  int thisWeek = 0, lastWeek = 0;

  /// Done-rate per weekday (Mon..Sun) over the last 8 weeks; null where under 3 logged days.
  final List<double?> weekday = List.filled(7, null);

  /// Share of the weekly goal hit, oldest → newest (12 weeks).
  final List<double> weekly = [];

  /// Misses with a note, newest first.
  final List<Entry> notes = [];

  /// Tag counts on done days, last 4 weeks.
  final Map<String, int> tags = {};

  double? get change => usual == null || usual == 0 ? null : (recent - usual!) / usual!;

  /// Slipping: well below your usual, or a long gap on a mission you do most days.
  bool get slipping => (change != null && change! <= -0.4) || ((sinceLast ?? 99) >= 5 && h.target >= 3 && (usual ?? 0) > 0);
  bool get improving => change != null && change! >= 0.15 && recent > 0;

  int? get worstDay {
    int? best;
    for (var i = 0; i < 7; i++) {
      final v = weekday[i];
      if (v == null) continue;
      if (best == null || v < weekday[best]!) best = i;
    }
    return best;
  }
}

class Connection {
  Connection(this.x, this.y, this.lag, this.withX, this.withoutX, this.days, this.xDone);
  final Habit x, y;
  final int lag; // 0 = same day, 1 = the day after
  final double withX, withoutX;
  final int days;
  final bool xDone; // the pattern is about days X was done (true) or missed (false)

  double get gap => (withX - withoutX).abs();
  int get hi => (math.max(withX, withoutX) * 100).round();
  int get lo => (math.min(withX, withoutX) * 100).round();

  static String did(Habit h, bool yes) =>
      h.isQuit ? (yes ? 'stay clean on ${h.name}' : 'slip on ${h.name}') : (yes ? 'do ${h.name}' : 'skip ${h.name}');

  /// e.g. "Eat clean: 81% on days you do Gym, vs 47% otherwise."
  String get sentence {
    final when = lag == 1 ? 'the day after you' : 'on days you';
    return '${y.name}: $hi% $when ${did(x, xDone)}, vs $lo% otherwise.';
  }
}

class Analytics {
  Analytics(this.store) : today = todayKey() {
    for (final h in store.habits) {
      missions.add(_mission(h));
    }
    connections = _connections();
  }

  final AppStore store;
  final int today;
  final List<MissionStats> missions = [];
  late final List<Connection> connections;

  bool ok(Habit h, int d) => store.entry(h.id, d)?.done == true;
  bool logged(Habit h, int d) => store.entry(h.id, d) != null;

  int _start(Habit h) {
    var s = h.createdDay;
    for (final e in store.entriesFor(h.id)) {
      if (e.day < s) s = e.day;
    }
    return s;
  }

  double _perWeek(Habit h, int fromAgo, int toAgo, int start) {
    final first = math.max(today - toAgo, start), last = today - fromAgo;
    if (last < first) return 0;
    var n = 0;
    for (var d = first; d <= last; d++) {
      if (ok(h, d)) n++;
    }
    return n / ((last - first + 1) / 7);
  }

  MissionStats _mission(Habit h) {
    final m = MissionStats(h);
    final start = _start(h);
    m.recent = _perWeek(h, 0, 13, start);
    if (start <= today - 21) m.usual = _perWeek(h, 14, 55, start);

    for (var a = 0; a <= today - start; a++) {
      if (ok(h, today - a)) {
        m.sinceLast = a;
        break;
      }
    }
    var run = 0;
    for (var d = start; d <= today; d++) {
      if (ok(h, d)) {
        run++;
        m.bestRun = math.max(m.bestRun, run);
      } else if (logged(h, d) || d < today) {
        run = 0;
      }
    }

    final ws = weekStartOf(today);
    for (var i = 0; i < 7; i++) {
      if (ok(h, ws + i)) m.thisWeek++;
      if (ok(h, ws - 7 + i)) m.lastWeek++;
    }
    for (var w = 11; w >= 0; w--) {
      final s = ws - 7 * w;
      var c = 0;
      for (var i = 0; i < 7; i++) {
        if (ok(h, s + i)) c++;
      }
      m.weekly.add(s + 6 < start ? 0 : math.min(1.0, c / h.target));
    }

    final wdDone = List.filled(7, 0), wdN = List.filled(7, 0);
    for (var a = 0; a < 56; a++) {
      final d = today - a;
      final e = store.entry(h.id, d);
      if (e == null) continue;
      final wd = dayDate(d).weekday - 1;
      wdN[wd]++;
      if (e.done) wdDone[wd]++;
    }
    for (var i = 0; i < 7; i++) {
      if (wdN[i] >= 3) m.weekday[i] = wdDone[i] / wdN[i];
    }

    final entries = store.entriesFor(h.id).toList()..sort((a, b) => b.day.compareTo(a.day));
    m.notes.addAll(entries.where((e) => !e.done && e.note.trim().isNotEmpty));
    for (final t in h.tags) {
      m.tags[t] = 0;
    }
    for (final e in entries) {
      if (e.day < today - 27 || !e.done) continue;
      for (final t in e.tags) {
        m.tags[t] = (m.tags[t] ?? 0) + 1;
      }
    }
    return m;
  }

  /// Does doing (or missing) X on a day — or the day before — go with doing Y?
  /// Needs 8+ logged days on both sides and a gap of 25 points or more.
  List<Connection> _connections() {
    final found = <Connection>[];
    final hs = store.habits;
    for (final x in hs) {
      for (final y in hs) {
        if (x.id == y.id) continue;
        for (final lag in const [0, 1]) {
          var yesN = 0, yesY = 0, noN = 0, noY = 0;
          for (var a = 0; a < 56; a++) {
            final d = today - a;
            final ex = store.entry(x.id, d - lag), ey = store.entry(y.id, d);
            if (ex == null || ey == null) continue;
            if (ex.done) {
              yesN++;
              if (ey.done) yesY++;
            } else {
              noN++;
              if (ey.done) noY++;
            }
          }
          if (yesN < 8 || noN < 8) continue;
          final p1 = yesY / yesN, p0 = noY / noN;
          if ((p1 - p0).abs() < 0.25) continue;
          // Phrase it around whichever side of X goes with doing Y more.
          found.add(p1 >= p0
              ? Connection(x, y, lag, p1, p0, yesN + noN, true)
              : Connection(x, y, lag, p0, p1, yesN + noN, false));
        }
      }
    }
    found.sort((a, b) => b.gap.compareTo(a.gap));
    final seen = <String>{};
    final out = <Connection>[];
    for (final c in found) {
      final k = ([c.x.id, c.y.id]..sort()).join('|');
      if (seen.add(k)) out.add(c);
      if (out.length == 3) break;
    }
    return out;
  }

  /// Share of weekly goals hit across all missions, oldest → newest (12 weeks).
  List<double> get overallWeekly {
    if (missions.isEmpty) return List.filled(12, 0);
    return [for (var i = 0; i < 12; i++) missions.map((m) => m.weekly[i]).reduce((a, b) => a + b) / missions.length];
  }

  ({int done, int missed}) counts(int days) {
    var done = 0, missed = 0;
    for (final h in store.habits) {
      for (var a = 0; a < days; a++) {
        final e = store.entry(h.id, today - a);
        if (e == null) continue;
        e.done ? done++ : missed++;
      }
    }
    return (done: done, missed: missed);
  }

  MissionStats? get biggestRisk {
    final s = missions.where((m) => m.slipping).toList()
      ..sort((a, b) => (a.change ?? 0).compareTo(b.change ?? 0));
    return s.isEmpty ? null : s.first;
  }

  /// The numbers the AI coach gets (and nothing else).
  Map<String, dynamic> toStats(String heroName) {
    String r1(double x) {
      final v = (x * 10).round() / 10;
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }

    return {
      'name': heroName,
      'week': 'Week of ${fmtDay(weekStartOf(today))}',
      'missions': [
        for (final m in missions)
          {
            'name': m.h.name,
            'kind': m.h.isQuit ? 'quit (a success is a clean day)' : 'build',
            'target_per_week': m.h.target,
            'this_week': m.thisWeek,
            'last_week': m.lastWeek,
            'last_2_weeks_per_week': r1(m.recent),
            'usual_per_week': m.usual == null ? null : r1(m.usual!),
            'days_since_last_success': m.sinceLast,
            if (m.worstDay != null && m.weekday[m.worstDay!]! <= 0.5)
              'worst_weekday': {'day': weekdayShort[m.worstDay!], 'done_rate': '${(m.weekday[m.worstDay!]! * 100).round()}%'},
            'recent_miss_notes': [for (final e in m.notes.take(6)) e.note],
            if (m.tags.isNotEmpty) 'tags_last_4_weeks': m.tags,
            if (m.h.why.trim().isNotEmpty) 'why_it_matters': m.h.why.trim(),
          }
      ],
      'connections': [for (final c in connections) '${c.sentence} (${c.days} days)'],
    };
  }
}
