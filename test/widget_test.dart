// Logic tests for streaks, weekly goals and scoring. Run: flutter test
import 'package:ember/models.dart';
import 'package:ember/stats.dart';
import 'package:flutter_test/flutter_test.dart';

Habit _habit(int target, int created) => Habit(
      id: 'x',
      name: 'x',
      emoji: '✨',
      kind: HabitKind.build,
      target: target,
      color: 0xFF39D353,
      tags: [],
      createdDay: created,
    );

void main() {
  // A Wednesday.
  final today = dayKey(DateTime(2026, 11, 11));
  final monday = weekStartOf(today);

  test('week starts on Monday', () {
    expect(dayDate(monday).weekday, DateTime.monday);
  });

  test('daily streak ignores an unlogged today', () {
    final done = {today - 1, today - 2, today - 3};
    final st = statsFor(_habit(7, today - 30), done, today);
    expect(st.streak, 3);
    expect(st.weekly, false);
  });

  test('daily streak includes today once logged', () {
    final done = {today, today - 1};
    expect(statsFor(_habit(7, today - 30), done, today).streak, 2);
  });

  test('weekly goal streak survives rest days', () {
    // Gym 4/7: last two full weeks hit 4, current week in progress.
    final done = <int>{
      for (final w in [monday - 7, monday - 14]) ...{w, w + 1, w + 3, w + 5},
      monday,
    };
    final st = statsFor(_habit(4, monday - 21), done, today);
    expect(st.weekly, true);
    expect(st.streak, 2);
    expect(st.weekDone, 1);
  });

  test('perfect 4 weeks scores 100', () {
    final done = {for (var d = today - 27; d <= today; d++) d};
    expect(statsFor(_habit(7, today - 40), done, today).score, 100);
  });

  test('level thresholds', () {
    expect(xpThreshold(1), 0);
    expect(xpThreshold(2), 100);
    expect(xpThreshold(3), 300);
    expect(habitSlots(1, false), 5);
    expect(habitSlots(4, false), 7);
  });
}
