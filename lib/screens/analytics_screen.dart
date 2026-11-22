import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../analytics.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/charts.dart';

/// Analytics: your log in numbers. No opinions here; that's Insights.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _weeks = 4;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final a = Analytics(s);
    final w = _weeks;
    final overall = a.overallWeekly;
    final cur = avgOf(overall.skip(12 - w)) ?? 0;
    final prev = avgOf(overall.sublist(math.max(0, 12 - 2 * w), 12 - w));
    final delta = prev == null ? null : ((cur - prev) * 100).round();
    final trend = trendOf(overall);
    final c = a.counts(w * 7);
    final ci = a.checkInDays(w * 7);
    final tagged = a.missions.where((m) => m.tags.isNotEmpty && m.tags.values.any((n) => n > 0)).toList();

    return AppScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ANALYTICS', style: heading(18).copyWith(letterSpacing: 3)),
                    const SizedBox(height: 3),
                    Text('Your log, in numbers', style: ui(12.5, color: AppColors.muted)),
                  ]),
                ),
                _Seg(value: w, onChanged: (v) => setState(() => _weeks = v)),
              ],
            ),
            if (s.habits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(child: Text('Add a mission on Home to see analytics.', style: ui(14, color: AppColors.muted))),
              )
            else ...[
              const SizedBox(height: 18),
              Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Ring(value: cur, size: 88),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Weekly goals hit', style: ui(12.5, color: AppColors.muted)),
                            const SizedBox(height: 6),
                            Text('${(cur * 100).round()}%', style: heading(30)),
                            const SizedBox(height: 6),
                            delta == null
                                ? Text('Comparison starts after $w weeks of logging', style: ui(12.5, color: AppColors.muted))
                                : Text.rich(TextSpan(children: [
                                    TextSpan(
                                        text: '${delta >= 0 ? '▲' : '▼'} ${delta.abs()} pts ',
                                        style: ui(12.5, weight: FontWeight.w700, color: delta >= 0 ? AppColors.green : AppColors.danger)),
                                    TextSpan(text: 'vs previous $w weeks', style: ui(12.5, color: AppColors.muted)),
                                  ])),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Trend(values: trend.sublist(math.max(0, trend.length - math.max(w, 6))), color: AppColors.green),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _Stat(
                    label: 'Days logged',
                    value: '${ci.logged}/${ci.total}',
                    sub: ci.logged == ci.total ? 'never skipped' : 'every mission logged',
                    color: ci.total > 0 && ci.logged == ci.total ? AppColors.green : null),
                const SizedBox(width: 10),
                _Stat(label: 'Done ✓', value: '${c.done}', sub: c.done + c.missed == 0 ? '—' : '${(c.done / (c.done + c.missed) * 100).round()}% of logs'),
                const SizedBox(width: 10),
                _Stat(label: 'Not done ✕', value: '${c.missed}', sub: 'you marked ✕'),
              ]),
              SectionLabel('Missions', trailing: Text('last $w weeks', style: ui(11, color: AppColors.faint))),
              Panel(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Column(children: [
                  for (final m in a.missions) _MissionRow(m: m, weeks: w, onTap: () => _detail(context, m)),
                ]),
              ),
              SectionLabel('Best and worst days', trailing: Text('% done · 8 weeks', style: ui(11, color: AppColors.faint))),
              Panel(child: _Heat(missions: a.missions)),
              for (final m in tagged) ...[
                SectionLabel('${m.h.name} split', trailing: Text('from your tags · 4 weeks', style: ui(11, color: AppColors.faint))),
                Panel(child: _TagBars(m: m)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _detail(BuildContext context, MissionStats m) {
    final color = Color(m.h.color);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cardHi,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(15)),
                child: Text(m.h.emoji, style: const TextStyle(fontSize: 23)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.h.name, style: heading(20)),
                  Text('Goal ${m.h.target} a week', style: ui(12.5, color: AppColors.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _Stat(label: 'Lately', value: _r1(m.recent), sub: 'per week', color: (m.change ?? 0) < 0 ? AppColors.danger : AppColors.green),
              const SizedBox(width: 10),
              _Stat(label: 'Usual', value: m.usual == null ? '—' : _r1(m.usual!), sub: 'per week'),
              const SizedBox(width: 10),
              _Stat(
                  label: 'Since last',
                  value: m.sinceLast == null ? '—' : '${m.sinceLast}d',
                  sub: 'best run ${m.bestRun}d',
                  color: (m.sinceLast ?? 0) >= 5 ? AppColors.danger : null),
            ]),
            SectionLabel('12-week trend', trailing: Text('% of weekly goal', style: ui(11, color: AppColors.faint))),
            Panel(child: _Trend(values: trendOf(m.weekly), color: color)),
            SectionLabel('By weekday', trailing: Text('% done · 8 weeks', style: ui(11, color: AppColors.faint))),
            Panel(child: _WeekdayBars(m: m, color: color)),
            if (m.notes.isNotEmpty) ...[
              SectionLabel('Why you missed', trailing: Text('your notes', style: ui(11, color: AppColors.faint))),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  for (final e in m.notes.take(6))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 74, child: Text(fmtDay(e.day), style: ui(12, color: AppColors.faint))),
                        Expanded(child: Text(e.note, style: ui(13.5, height: 1.4))),
                      ]),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _r1(double x) {
  final v = (x * 10).round() / 10;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Seg extends StatelessWidget {
  const _Seg({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.cardHi,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          for (final w in const [4, 12])
            GestureDetector(
              onTap: () => onChanged(w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: w == value ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('${w}W',
                    style: ui(12, weight: FontWeight.w700, color: w == value ? const Color(0xFF0B0F05) : AppColors.muted)),
              ),
            ),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.sub, this.color});
  final String label, value, sub;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Panel(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(), style: eyebrow(size: 9)),
            const SizedBox(height: 7),
            Text(value, style: heading(18, color: color ?? AppColors.text)),
            const SizedBox(height: 4),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(11, color: AppColors.muted)),
          ]),
        ),
      );
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.m, required this.weeks, required this.onTap});
  final MissionStats m;
  final int weeks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(m.h.color);
    final cur = avgOf(m.weekly.skip(12 - weeks)) ?? 0;
    final prev = avgOf(m.weekly.sublist(math.max(0, 12 - 2 * weeks), 12 - weeks));
    final d = prev == null ? null : ((cur - prev) * 100).round();
    final spark = trendOf(m.weekly);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)),
            child: Text(m.h.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(15, weight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${_r1(m.recent)}/wk · goal ${m.h.target}', style: ui(12, color: AppColors.muted)),
            ]),
          ),
          if (spark.length >= 2) Sparkline(values: spark.sublist(math.max(0, spark.length - math.max(weeks, 6))), color: color),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(cur * 100).round()}%', style: heading(15)),
              const SizedBox(height: 2),
              Text(d == null ? 'new' : '${d >= 0 ? '▲' : '▼'} ${d.abs()}',
                  style: ui(11.5, weight: FontWeight.w700, color: d == null ? AppColors.faint : d >= 0 ? AppColors.green : AppColors.danger)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Heat extends StatelessWidget {
  const _Heat({required this.missions});
  final List<MissionStats> missions;

  @override
  Widget build(BuildContext context) {
    MissionStats? worstM;
    int? worstD;
    for (final m in missions) {
      final d = m.worstDay;
      if (d == null) continue;
      if (worstM == null || m.weekday[d]! < worstM.weekday[worstD!]!) {
        worstM = m;
        worstD = d;
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const SizedBox(width: 34),
        for (final l in weekdayLetters) Expanded(child: Center(child: Text(l, style: ui(11, color: AppColors.muted)))),
      ]),
      const SizedBox(height: 6),
      for (final m in missions)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            SizedBox(width: 34, child: Text(m.h.emoji, style: const TextStyle(fontSize: 17))),
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Container(
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: m.weekday[i] == null
                        ? AppColors.empty.withValues(alpha: .5)
                        : Color.lerp(AppColors.empty, Color(m.h.color), .12 + m.weekday[i]! * .76)!
                            .withValues(alpha: m.weekdayN[i] < 3 ? .45 : 1),
                  ),
                  child: Text(m.weekday[i] == null ? '' : '${(m.weekday[i]! * 100).round()}',
                      style: ui(10.5,
                          weight: FontWeight.w700,
                          color: (m.weekday[i] ?? 0) > .55 ? const Color(0xB3000000) : AppColors.muted)),
                ),
              ),
          ]),
        ),
      if (missions.any((m) => m.weekdayN.any((n) => n > 0 && n < 3))) ...[
        const SizedBox(height: 6),
        Text('Faded squares are based on fewer than 3 days. They firm up as you log.', style: ui(11.5, color: AppColors.faint)),
      ],
      if (worstM != null) ...[
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: ui(12.5, color: AppColors.muted), children: [
          TextSpan(text: '${worstM.h.name} on ${weekdayLong[worstD!]}s: '),
          TextSpan(
              text: '${(worstM.weekday[worstD]! * 100).round()}%',
              style: ui(12.5, weight: FontWeight.w700, color: AppColors.danger)),
          const TextSpan(text: '. Your weakest spot.'),
        ])),
      ],
    ]);
  }
}

class _TagBars extends StatelessWidget {
  const _TagBars({required this.m});
  final MissionStats m;

  @override
  Widget build(BuildContext context) {
    final entries = m.tags.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.fold<int>(1, (a, e) => math.max(a, e.value));
    final zero = entries.where((e) => e.value == 0).map((e) => e.key).toList();
    final color = Color(m.h.color);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(width: 92, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(13))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: e.value / max,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: .06),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            SizedBox(
                width: 26,
                child: Text('${e.value}',
                    textAlign: TextAlign.right,
                    style: ui(13, weight: FontWeight.w700, color: e.value == 0 ? AppColors.danger : AppColors.text))),
          ]),
        ),
      if (zero.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text.rich(TextSpan(style: ui(12.5, color: AppColors.muted), children: [
          const TextSpan(text: 'Not in 4 weeks: '),
          TextSpan(text: zero.join(', '), style: ui(12.5, weight: FontWeight.w600)),
        ])),
      ],
    ]);
  }
}

class _WeekdayBars extends StatelessWidget {
  const _WeekdayBars({required this.m, required this.color});
  final MissionStats m;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(m.weekday[i] == null ? '—' : '${(m.weekday[i]! * 100).round()}',
                      style: ui(11, weight: FontWeight.w600, color: (m.weekday[i] ?? 1) < .3 ? AppColors.danger : AppColors.muted)),
                  const SizedBox(height: 5),
                  Container(
                    height: 4 + (m.weekday[i] ?? 0) * 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: (m.weekday[i] ?? 1) < .3 ? AppColors.danger : color.withValues(alpha: .35 + (m.weekday[i] ?? 0) * .65),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(weekdayLetters[i], style: ui(11, color: AppColors.muted)),
                ]),
              ),
            ),
        ]),
      );
}

/// Trend chart, or a note until there are two weeks to draw.
class _Trend extends StatelessWidget {
  const _Trend({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => values.length >= 2
      ? AreaChart(values: values, color: color)
      : SizedBox(
          height: 70,
          child: Center(child: Text('Your trend line appears after your second week.', style: ui(12.5, color: AppColors.muted))),
        );
}
