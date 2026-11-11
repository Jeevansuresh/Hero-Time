# Ember — habit tracker

Minimal, dark, local-first habit tracker for Android (Flutter). GitHub-style contribution
grids, weekly goals, notes per day, a daily reminder at a time you choose, and a companion
that evolves as you stay consistent.

## Run it

Needs Flutter 3.27+ (stable) and an Android device or emulator.

```bash
cd ember
flutter create --platforms=android --org com.jeevan --project-name ember .
dart run tool/setup_android.dart      # enables desugaring + notification permissions
flutter pub get
flutter run                           # or: flutter build apk --release
```

`flutter create .` only adds the missing `android/` folder; it doesn't touch `lib/`.
The setup script patches `android/app/build.gradle(.kts)` and `AndroidManifest.xml` — run it once.

## What's in it

**Habits**
- Two kinds: **Build** (do it: gym, sleep) and **Quit** (avoid it: sugar, doomscrolling).
- Weekly goal 1–7 days. `No sugar 6/7` = one free day a week. `Gym 4/7` = rest days never hurt.
- Quick tags per habit (gym ships with muscle groups) + a free-text note per day.
- Starts with: No sugar (6/7), Gym (4/7), Sleep well (7/7), No doomscrolling (7/7), Eat clean (7/7). Edit or replace any of them.

**Tracking**
- Tap ✓ to log today. Long-press (or "Add details" in the toast) for notes/tags, or to mark a miss/slip.
- Tap any square in a habit's grid to backfill or edit that day.
- Home grid = all habits combined (shade = share of habits done that day). Each habit has its own grid.

**Numbers**
- Streak: days for daily habits; *weeks where you hit the goal* for anything under 7/7.
- Score (0–100): adherence to your weekly goal over the last 4 weeks, averaged into an overall score.
- Gym-style habits show a 30-day tag breakdown (which muscles you hit, and which you haven't).

**Aliens**
- XP: +10 per successful day, +3 if you add a note/tags, +40 per habit per week the goal is met.
- Nine original aliens unlock as you level: Pip, Moji (Lv2), Bramble (4), Nimbo (6), Clink (8),
  Luma (10), Gnash (13), Orbis (16), Sol (20). Tap one on the companion screen to transform.
- Levels also unlock extra habit slots (5 to start; +1 at Lv 2, 4, 7, 10, 15) and new colours.
- Sound effects for logging, goals, level-ups, unlocks and transforms (toggle in Settings).
- Settings → "Unlock everything" removes the gates if you just want the tracker.

**Reminder**
- One daily notification at your chosen time (default 9:30 PM). It names the habits still unlogged,
  and is skipped on days you've already logged everything (toggleable).
- Uses inexact alarms (battery-friendly, no special permission), so it can land a few minutes late.

**Data**
- Everything lives on the device (SharedPreferences). Export/import a JSON backup from Settings.

## Files

```
lib/
  main.dart                  app entry, lifecycle refresh
  models.dart                Habit, Entry, Settings, date helpers, default habits
  store.dart                 state + persistence + backup
  stats.dart                 streaks, weekly goals, score, XP/levels, unlocks
  notifications.dart         daily reminder planning
  theme.dart                 colours, type, shared widgets
  widgets/heatmap.dart       contribution grid
  widgets/character.dart     the companion (drawn in code, animated)
  widgets/habit_card.dart    home habit card
  screens/                   home, habit detail, editor, log sheet, companion, settings
tool/setup_android.dart      one-time Android patch
test/widget_test.dart        logic tests (flutter test)
```

## Ideas for later
- Home-screen widget with today's checkboxes.
- Streak freeze earned per level (protects one missed day).
- Per-habit reminder times.
- Numeric values (sleep hours, weight lifted) with a small trend line.
- Monthly recap card you can share.
