import 'package:flutter/material.dart';

import '../analytics.dart';
import '../coach.dart';
import '../sfx.dart';
import '../store.dart';
import '../theme.dart';
import 'root_shell.dart';

/// Insights: the coach. A weekly debrief from Claude Haiku, the biggest risk,
/// and connections between your missions. Straight talk only.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Debrief? _debrief;
  bool _hasKey = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = await Coach.apiKey();
    final d = await Coach.cached();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null;
      _debrief = d;
    });
  }

  Future<void> _write(Analytics a, String name) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await Coach.write(a.toStats(name));
      if (!mounted) return;
      Sfx.play('goal');
      setState(() => _debrief = d);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final a = Analytics(s);
    // Re-check the key whenever this tab rebuilds (it may have been added in Settings).
    Coach.apiKey().then((k) {
      if (mounted && (k != null) != _hasKey) setState(() => _hasKey = k != null);
    });
    final week = a.toStats(s.settings.petName)['week'] as String;
    final fresh = _debrief != null && _debrief!.week == week;

    return AppScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
          children: [
            Text('INSIGHTS', style: heading(18).copyWith(letterSpacing: 3)),
            const SizedBox(height: 3),
            Text('Your coach reads your log', style: ui(12.5, color: AppColors.muted)),
            const SizedBox(height: 18),
            if (s.habits.isEmpty)
              Center(child: Text('Add a mission on Home first.', style: ui(14, color: AppColors.muted)))
            else ...[
              _CoachCard(
                analytics: a,
                debrief: _debrief,
                fresh: fresh,
                hasKey: _hasKey,
                loading: _loading,
                error: _error,
                onWrite: () => _write(a, s.settings.petName),
              ),
              if (a.biggestRisk != null) ...[
                const SectionLabel('Biggest risk'),
                _RiskCard(m: a.biggestRisk!, stakes: fresh ? _debrief!.stakes : null),
              ],
              SectionLabel('Connections', trailing: Text('patterns in your log', style: ui(11, color: AppColors.faint))),
              if (a.connections.isEmpty)
                Panel(
                  child: Text(
                    'No strong patterns yet. Keep logging both ✓ and ✕ every day; connections show up once there are 8+ days on each side.',
                    style: ui(13, color: AppColors.muted, height: 1.45),
                  ),
                )
              else ...[
                for (final c in a.connections) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ConnCard(c: c)),
                Text('Patterns, not proof. Each needs 8+ days on both sides.', style: ui(11.5, color: AppColors.faint)),
              ],
              if (fresh && _debrief!.plan.isNotEmpty) ...[
                const SectionLabel('Your plan for next week'),
                _PlanCard(
                  debrief: _debrief!,
                  onAccept: () async {
                    await Coach.acceptPlan(_debrief!);
                    Sfx.play('check');
                    setState(() {});
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.analytics,
    required this.debrief,
    required this.fresh,
    required this.hasKey,
    required this.loading,
    required this.error,
    required this.onWrite,
  });
  final Analytics analytics;
  final Debrief? debrief;
  final bool fresh, hasKey, loading;
  final String? error;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final d = fresh ? debrief : null;
    // Without an AI debrief, show the rule-based read of the same numbers.
    final wins = d?.wins ?? [for (final m in analytics.missions.where((m) => m.improving).take(2)) '${m.h.name}: ${_r1(m.recent)} a week lately, up from ${_r1(m.usual!)}.'];
    final slips = d?.lacking ??
        [
          for (final m in analytics.missions.where((m) => m.slipping).take(3))
            '${m.h.name}: ${_r1(m.recent)} a week lately vs your usual ${_r1(m.usual ?? 0)}${(m.sinceLast ?? 0) >= 3 ? ', ${m.sinceLast} days since the last one' : ''}.'
        ];
    final headline = d?.headline ??
        (slips.isEmpty
            ? 'Nothing is slipping. Keep stacking days.'
            : '${analytics.biggestRisk?.h.name ?? 'Something'} is slipping. Time to get it back.');

    return Panel(
      glow: AppColors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(d != null ? 'WEEKLY DEBRIEF' : 'THIS WEEK', style: eyebrow(size: 10, color: AppColors.green).copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (d != null)
              GestureDetector(
                onTap: loading ? null : onWrite,
                child: Text(loading ? 'Writing…' : 'Rewrite', style: ui(11.5, weight: FontWeight.w600, color: AppColors.muted)),
              ),
          ]),
          const SizedBox(height: 12),
          Text(headline, style: heading(17, color: AppColors.text).copyWith(height: 1.35)),
          if (wins.isNotEmpty || slips.isNotEmpty) const SizedBox(height: 14),
          for (final w in wins) _Line(text: w, good: true),
          for (final l in slips) _Line(text: l, good: false),
          if (d != null && d.connection.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(d.connection, style: ui(13, color: AppColors.muted, height: 1.45)),
          ],
          const SizedBox(height: 14),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(error!, style: ui(12.5, color: AppColors.danger, height: 1.4)),
            ),
          if (!hasKey)
            _Button(
              label: 'Add your Claude API key',
              sub: 'Settings → AI coach. Unlocks the written weekly debrief.',
              onTap: () => RootShell.goTo(context, 3),
            )
          else if (d == null)
            _Button(
              label: loading ? 'Writing your debrief…' : 'Write this week\'s debrief',
              sub: 'Claude Haiku reads your numbers · about 0.1¢',
              onTap: loading ? null : onWrite,
              loading: loading,
            )
          else
            Text('✦ Written by Claude Haiku from your log', style: ui(11, color: AppColors.faint)),
        ],
      ),
    );
  }
}

String _r1(double x) {
  final v = (x * 10).round() / 10;
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _Line extends StatelessWidget {
  const _Line({required this.text, required this.good});
  final String text;
  final bool good;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (good ? AppColors.green : AppColors.danger).withValues(alpha: .14),
            ),
            child: Text(good ? '✓' : '!',
                style: ui(11, weight: FontWeight.w800, color: good ? AppColors.green : AppColors.danger)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: ui(13.5, color: const Color(0xFFC9D3CB), height: 1.45))),
        ]),
      );
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.sub, required this.onTap, this.loading = false});
  final String label, sub;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.green,
            disabledBackgroundColor: AppColors.green.withValues(alpha: .4),
            foregroundColor: const Color(0xFF0B0F05),
            minimumSize: const Size(64, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (loading) ...[
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0B0F05))),
              const SizedBox(width: 10),
            ],
            Text(label, style: ui(14, weight: FontWeight.w700, color: const Color(0xFF0B0F05))),
          ]),
        ),
        const SizedBox(height: 8),
        Text(sub, textAlign: TextAlign.center, style: ui(11.5, color: AppColors.faint)),
      ]);
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({required this.m, this.stakes});
  final MissionStats m;
  final String? stakes;

  static bool _training(String n) => RegExp(r'gym|workout|train|lift|run|sport|exercise|fit', caseSensitive: false).hasMatch(n);

  @override
  Widget build(BuildContext context) {
    final h = m.h;
    final title = _training(h.name) ? "Bro, you've been skipping the ${h.name.toLowerCase()}. A lot." : '${h.name} is slipping. Badly.';
    final stake = stakes ??
        (_training(h.name)
            ? 'A few weeks off and strength starts sliding, then the muscle goes with it. Keep eating the same and the scale goes up instead.'
            : "Two bad weeks is how habits die quietly. The streak you built was the hard part. Don't hand it back.");
    Widget stat(String k, String v, String unit, {bool bad = false}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k, style: ui(11.5, color: AppColors.muted)),
            const SizedBox(height: 4),
            Text.rich(TextSpan(children: [
              TextSpan(text: v, style: heading(19, color: bad ? AppColors.danger : AppColors.text)),
              TextSpan(text: unit, style: ui(11.5, color: AppColors.muted)),
            ])),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.danger.withValues(alpha: .08), AppColors.danger.withValues(alpha: .01)],
        ),
        border: Border.all(color: AppColors.danger.withValues(alpha: .25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('● ${h.name.toUpperCase()} IS SLIPPING', style: eyebrow(size: 10, color: AppColors.danger).copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(title, style: heading(16.5).copyWith(height: 1.35)),
        const SizedBox(height: 14),
        Row(children: [
          stat('Lately', _r1(m.recent), '/wk', bad: true),
          stat('Your usual', m.usual == null ? '—' : _r1(m.usual!), '/wk'),
          stat('Last one', m.sinceLast == null ? '—' : '${m.sinceLast}', ' days', bad: (m.sinceLast ?? 0) >= 5),
        ]),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stake, style: ui(13.5, color: const Color(0xFFC9D3CB), height: 1.5)),
            if (h.why.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Your why: “${h.why.trim()}”', style: ui(12, color: AppColors.muted, height: 1.4)),
            ] else ...[
              const SizedBox(height: 8),
              Text('Add "Why this matters" to ${h.name} and the coach will hold you to it.',
                  style: ui(11.5, color: AppColors.faint, height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _ConnCard extends StatelessWidget {
  const _ConnCard({required this.c});
  final Connection c;

  @override
  Widget build(BuildContext context) {
    final color = Color(c.y.color);
    Widget bar(double v, Color col, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: .07),
                valueColor: AlwaysStoppedAnimation(col),
              ),
            ),
            const SizedBox(height: 5),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ui(11, color: AppColors.muted)),
          ]),
        );
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 70,
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '+${c.hi - c.lo}', style: heading(22, color: color)),
              TextSpan(text: ' pts', style: ui(11.5, color: AppColors.muted)),
            ])),
          ),
          Expanded(
            child: Text('${c.x.emoji} → ${c.y.emoji}  ${c.sentence}', style: ui(13.5, color: const Color(0xFFC9D3CB), height: 1.45)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          bar(c.hi / 100, color, '${c.lag == 1 ? 'day after ' : ''}${Connection.did(c.x, c.xDone)} · ${c.hi}%'),
          const SizedBox(width: 8),
          bar(c.lo / 100, AppColors.faint, 'otherwise · ${c.lo}%'),
        ]),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.debrief, required this.onAccept});
  final Debrief debrief;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.green.withValues(alpha: .09), AppColors.green.withValues(alpha: .02)],
          ),
          border: Border.all(color: AppColors.green.withValues(alpha: .25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ONE THING', style: eyebrow(size: 10, color: AppColors.green).copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(debrief.plan, style: ui(15, weight: FontWeight.w600, height: 1.45)),
          const SizedBox(height: 14),
          debrief.accepted
              ? Row(children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
                  const SizedBox(width: 8),
                  Text("Plan accepted. Now go do it.", style: ui(13.5, weight: FontWeight.w600, color: AppColors.green)),
                ])
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: const Color(0xFF0B0F05),
                      minimumSize: const Size(64, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Accept plan', style: ui(14, weight: FontWeight.w700, color: const Color(0xFF0B0F05))),
                  ),
                ),
        ]),
      );
}
