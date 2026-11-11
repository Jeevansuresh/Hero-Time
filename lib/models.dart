import 'theme.dart';

// ---------- Dates ----------
// Days are stored as integer keys (days since epoch, local calendar date),
// which keeps math simple and immune to DST.

int dayKey(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

DateTime dayDate(int key) =>
    DateTime.fromMillisecondsSinceEpoch(key * 86400000, isUtc: true);

int todayKey() => dayKey(DateTime.now());

/// Monday of the week containing [day].
int weekStartOf(int day) => day - (dayDate(day).weekday - 1);

const monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String fmtDay(int key) {
  final d = dayDate(key);
  return '${weekdayShort[d.weekday - 1]}, ${d.day} ${monthShort[d.month - 1]}';
}

String fmtLong(int key) {
  final d = dayDate(key);
  return '${weekdayLong[d.weekday - 1]} · ${d.day} ${monthLong[d.month - 1]}';
}

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

// ---------- Habit ----------

enum HabitKind { build, quit }

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.kind,
    required this.target,
    required this.color,
    required this.tags,
    required this.createdDay,
  });

  final String id;
  String name;
  String emoji;
  HabitKind kind;

  /// Successful days wanted per week (1–7). For quit habits a success is a clean day.
  int target;
  int color;

  /// Quick tags offered when logging (e.g. muscle groups for gym).
  List<String> tags;
  int createdDay;

  bool get isQuit => kind == HabitKind.quit;
  String get doneLabel => isQuit ? 'Clean' : 'Done';
  String get missLabel => isQuit ? 'Slipped' : 'Missed';
  String get goalText => target == 7
      ? (isQuit ? 'clean every day' : 'every day')
      : (isQuit ? '$target clean days a week' : '$target days a week');

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'kind': kind.name,
        'target': target,
        'color': color,
        'tags': tags,
        'createdDay': createdDay,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        emoji: (j['emoji'] ?? '✨') as String,
        kind: j['kind'] == 'quit' ? HabitKind.quit : HabitKind.build,
        target: ((j['target'] as num?)?.toInt() ?? 7).clamp(1, 7).toInt(),
        color: (j['color'] as num?)?.toInt() ?? habitPalette[0],
        tags: ((j['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
        createdDay: (j['createdDay'] as num?)?.toInt() ?? todayKey(),
      );

  Habit copy() => Habit.fromJson(toJson());
}

// ---------- Entry (one log per habit per day) ----------

class Entry {
  Entry({
    required this.habitId,
    required this.day,
    required this.done,
    this.note = '',
    List<String>? tags,
  }) : tags = tags ?? [];

  final String habitId;
  final int day;
  bool done;
  String note;
  List<String> tags;

  bool get hasDetails => note.trim().isNotEmpty || tags.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'h': habitId,
        'd': day,
        'ok': done,
        if (note.isNotEmpty) 'n': note,
        if (tags.isNotEmpty) 't': tags,
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        habitId: j['h'] as String,
        day: (j['d'] as num).toInt(),
        done: (j['ok'] ?? true) as bool,
        note: (j['n'] ?? '') as String,
        tags: ((j['t'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

// ---------- Settings ----------

class Settings {
  bool reminderOn = true;
  int hour = 21;
  int minute = 30;
  bool skipIfLogged = true;
  bool unlockAll = false;
  String petName = 'Ember';
  String alien = 'pip';
  bool sound = true;

  Map<String, dynamic> toJson() => {
        'reminderOn': reminderOn,
        'hour': hour,
        'minute': minute,
        'skipIfLogged': skipIfLogged,
        'unlockAll': unlockAll,
        'petName': petName,
        'alien': alien,
        'sound': sound,
      };

  static Settings fromJson(Map<String, dynamic> j) => Settings()
    ..reminderOn = (j['reminderOn'] ?? true) as bool
    ..hour = (j['hour'] as num?)?.toInt() ?? 21
    ..minute = (j['minute'] as num?)?.toInt() ?? 30
    ..skipIfLogged = (j['skipIfLogged'] ?? true) as bool
    ..unlockAll = (j['unlockAll'] ?? false) as bool
    ..petName = (j['petName'] ?? 'Ember') as String
    ..alien = (j['alien'] ?? 'pip') as String
    ..sound = (j['sound'] ?? true) as bool;
}

List<Habit> defaultHabits() {
  final t = todayKey();
  return [
    Habit(
      id: 'sugar',
      name: 'No sugar',
      emoji: '🍬',
      kind: HabitKind.quit,
      target: 6,
      color: habitPalette[2],
      tags: [],
      createdDay: t,
    ),
    Habit(
      id: 'gym',
      name: 'Gym',
      emoji: '🏋️',
      kind: HabitKind.build,
      target: 4,
      color: habitPalette[0],
      tags: ['Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps', 'Legs', 'Core', 'Cardio'],
      createdDay: t,
    ),
    Habit(
      id: 'sleep',
      name: 'Sleep well',
      emoji: '🌙',
      kind: HabitKind.build,
      target: 7,
      color: habitPalette[1],
      tags: ['7h+', '8h+', 'In bed by 12', 'No screens', 'Woke rested'],
      createdDay: t,
    ),
    Habit(
      id: 'quit',
      name: 'No doomscrolling',
      emoji: '📵',
      kind: HabitKind.quit,
      target: 7,
      color: habitPalette[3],
      tags: [],
      createdDay: t,
    ),
    Habit(
      id: 'eat',
      name: 'Eat clean',
      emoji: '🥗',
      kind: HabitKind.build,
      target: 7,
      color: habitPalette[4],
      tags: ['Under calories', 'High protein', 'Home cooked', 'No junk'],
      createdDay: t,
    ),
  ];
}
