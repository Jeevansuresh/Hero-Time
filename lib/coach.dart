import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The AI coach: Claude Haiku writes the weekly debrief from numbers the app
/// already worked out. Your API key is stored encrypted on this phone only.
class Coach {
  static const model = 'claude-haiku-5-5';
  static const _keyName = 'claude_api_key';
  static const _storage = FlutterSecureStorage();
  static final _cacheKey = 'debrief_v1';

  static String? _key;
  static bool _loaded = false;

  static Future<String?> apiKey() async {
    if (!_loaded) {
      _loaded = true;
      try {
        _key = await _storage.read(key: _keyName);
      } catch (e) {
        debugPrint('Coach: reading key failed: $e');
      }
    }
    return _key;
  }

  static Future<void> setKey(String? key) async {
    final k = key?.trim();
    _key = (k == null || k.isEmpty) ? null : k;
    _loaded = true;
    if (_key == null) {
      await _storage.delete(key: _keyName);
    } else {
      await _storage.write(key: _keyName, value: _key);
    }
  }

  static const _system = '''You are the Omnitrix, the coach inside Hero Time, a Ben 10 themed habit app. Write the user's weekly debrief from the stats you are given.

Voice: straight talk only. Talk like a close friend who calls him out: short, punchy sentences, plain words, a little humour is fine, "bro" at most once. Never insulting, never preachy.

Rules:
- The stats are everything the app knows: which missions were done or missed each day, notes on missed days, and tags. Use only numbers and facts that appear in them. Never mention mood, energy, weight, hours of sleep or anything else that isn't tracked.
- "quit" missions count clean days, so a high number there is good.
- Write rates as percentages (46%, not 0.46) and counts as "4 of 4".
- Health statements stay general and accurate (for example: strength and muscle start to fade after a few weeks without training; eating the same while training less tends to add weight). No medical advice.
- Quote the user's own "why it matters" when that mission is slipping.
- Connections are patterns, not proof; say so briefly. If there are none, say what to keep logging instead.
- Wins are only things that went well (on or above usual or target). If only one thing went well, give one win; never dress up a slip as a win.
- Each line is about one mission; don't mix facts from different missions in one line.
- Exactly one plan for next week: specific, small, doable, tied to what the stats show.
- Keep every field short; this is read on a phone.''';

  static const _schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['headline', 'wins', 'lacking', 'connection', 'stakes', 'plan'],
    'properties': {
      'headline': {'type': 'string', 'description': 'One sentence summing up the week.'},
      'wins': {'type': 'array', 'items': {'type': 'string'}, 'description': '0-2 short lines on what went well.'},
      'lacking': {'type': 'array', 'items': {'type': 'string'}, 'description': '1-3 short lines on what slipped, with numbers.'},
      'connection': {'type': 'string', 'description': 'The most useful pattern from the connections list, in plain words.'},
      'stakes': {'type': 'string', 'description': "What happens if the biggest slip continues, tied to the user's own why."},
      'plan': {'type': 'string', 'description': 'One specific plan for next week.'},
    },
  };

  static Future<http.Response> _post(String key, Map<String, dynamic> body) => http
      .post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': key,
          'anthropic-version': '2026-10-21',
          'content-type': 'application/json',
          'anthropic-dangerous-direct-browser-access': 'true', // only matters in the web preview
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 90));

  static String _error(http.Response r) {
    try {
      final m = (jsonDecode(r.body) as Map)['error']?['message'];
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return switch (r.statusCode) {
      401 => 'That API key was rejected. Check it in Settings.',
      429 => 'Too many requests right now. Try again in a minute.',
      _ => 'Claude returned an error (${r.statusCode}).',
    };
  }

  /// Tiny call to check the key works. Returns null on success, or an error message.
  static Future<String?> test(String key) async {
    try {
      final r = await _post(key, {
        'model': model,
        'max_tokens': 64,
        'messages': [
          {'role': 'user', 'content': 'Reply with the single word: ready'}
        ],
      });
      return r.statusCode == 200 ? null : _error(r);
    } catch (e) {
      return 'Could not reach Claude. Check your internet connection.';
    }
  }

  /// Writes the debrief. Throws a readable message on failure.
  static Future<Debrief> write(Map<String, dynamic> stats) async {
    final key = await apiKey();
    if (key == null) throw 'Add your Claude API key in Settings first.';
    http.Response r;
    try {
      r = await _post(key, {
        'model': model,
        'max_tokens': 4000,
        'system': _system,
        'output_config': {
          'effort': 'medium',
          'format': {'type': 'json_schema', 'schema': _schema},
        },
        'messages': [
          {'role': 'user', 'content': "This week's stats:\n${const JsonEncoder.withIndent(' ').convert(stats)}"}
        ],
      });
    } catch (_) {
      throw 'Could not reach Claude. Check your internet connection.';
    }
    if (r.statusCode != 200) throw _error(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['stop_reason'] == 'refusal') throw 'Claude declined to write this one. Try again later.';
    final text = (j['content'] as List).cast<Map>().firstWhere((b) => b['type'] == 'text', orElse: () => {})['text'];
    if (text is! String) throw 'Claude sent back an empty debrief. Try again.';
    final d = Debrief.fromJson(jsonDecode(text) as Map<String, dynamic>, week: stats['week'] as String);
    await _save(d);
    return d;
  }

  // ---- cache: one debrief per week ----

  static Future<Debrief?> cached() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return Debrief.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _save(Debrief d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_cacheKey, jsonEncode(d.toJson()));
  }

  static Future<void> acceptPlan(Debrief d) async {
    d.accepted = true;
    await _save(d);
  }
}

class Debrief {
  Debrief({
    required this.week,
    required this.headline,
    required this.wins,
    required this.lacking,
    required this.connection,
    required this.stakes,
    required this.plan,
    this.accepted = false,
  });

  final String week, headline, connection, stakes, plan;
  final List<String> wins, lacking;
  bool accepted;

  factory Debrief.fromJson(Map<String, dynamic> j, {String? week}) => Debrief(
        week: week ?? (j['week'] ?? '') as String,
        headline: (j['headline'] ?? '') as String,
        wins: [for (final x in (j['wins'] as List? ?? const [])) '$x'],
        lacking: [for (final x in (j['lacking'] as List? ?? const [])) '$x'],
        connection: (j['connection'] ?? '') as String,
        stakes: (j['stakes'] ?? '') as String,
        plan: (j['plan'] ?? '') as String,
        accepted: (j['accepted'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'week': week,
        'headline': headline,
        'wins': wins,
        'lacking': lacking,
        'connection': connection,
        'stakes': stakes,
        'plan': plan,
        'accepted': accepted,
      };
}
