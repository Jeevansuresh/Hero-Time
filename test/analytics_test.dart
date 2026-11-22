// Analytics on a short log: weeks before you started must not count as 0%.
import 'dart:convert';

import 'package:ember/analytics.dart';
import 'package:ember/models.dart';
import 'package:ember/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppStore> storeWith({required int startedDaysAgo, required bool Function(int ago) done}) async {
    final today = todayKey();
    final habit = Habit(
      id: 'sugar',
      name: 'No sugar',
      emoji: '🍬',
      kind: HabitKind.quit,
      target: 6,
      color: 0xFFFF6A1A,
      tags: [],
      createdDay: today - startedDaysAgo,
    );
    final entries = [
      for (var ago = startedDaysAgo; ago >= 1; ago--) {'h': 'sugar', 'd': today - ago, 'ok': done(ago)}
    ];
    SharedPreferences.setMockInitialValues({
      'flutter.habits_v1': jsonEncode([habit.toJson()]),
      'flutter.entries_v1': jsonEncode(entries),
    });
    final s = AppStore();
    await s.load();
    return s;
  }

  test('weeks before the mission started are skipped, not counted as 0%', () async {
    // Clean every day for the last 12 days.
    final a = Analytics(await storeWith(startedDaysAgo: 12, done: (_) => true));
    final m = a.missions.single;
    // At most 3 calendar weeks touch the last 12 days; the rest have no data.
    expect(m.weekly.where((w) => w != null).length, lessThanOrEqualTo(3));
    expect(m.weekly.first, isNull);
    // Every week with data is near or at 100%, so the average must be high, not ~25%.
    final last4 = avgOf(m.weekly.skip(8))!;
    expect(last4, greaterThan(0.75));
    // Nothing to compare against yet.
    expect(avgOf(m.weekly.sublist(4, 8)), isNull);
  });

  test('weekday heatmap shows data after only a week or two', () async {
    final a = Analytics(await storeWith(startedDaysAgo: 10, done: (ago) => ago.isEven));
    final m = a.missions.single;
    expect(m.weekday.where((v) => v != null).length, 7);
    // With under 3 days per weekday there is no "weakest day" claim yet.
    expect(m.worstDay, isNull);
  });

  test('a day logged with ✕ still counts as checked in', () async {
    // Logged every day, but half of them as ✕.
    final a = Analytics(await storeWith(startedDaysAgo: 12, done: (ago) => ago.isEven));
    final ci = a.checkInDays(28);
    expect(ci.total, greaterThan(0));
    expect(ci.logged, ci.total);
  });

  test('overall trend starts at the first week with data', () async {
    final a = Analytics(await storeWith(startedDaysAgo: 12, done: (_) => true));
    expect(trendOf(a.overallWeekly).length, lessThanOrEqualTo(3));
  });
}
