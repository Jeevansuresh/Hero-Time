import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// GitHub-style contribution grid. Columns are weeks (Mon→Sun top to bottom),
/// newest week on the right. Scrolls horizontally for longer history.
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.valueFor,
    required this.color,
    this.weeks = 26,
    this.onTap,
    this.missedFor,
    this.cell = 13,
    this.gap = 3.5,
  });

  /// 0..1 intensity for a day; negative = before tracking started.
  final double Function(int day) valueFor;
  final Color color;
  final int weeks;
  final void Function(int day)? onTap;

  /// Days marked as missed (✕) are drawn red, so they stand apart from unlogged days.
  final bool Function(int day)? missedFor;
  final double cell;
  final double gap;

  static const _labelH = 16.0;

  @override
  Widget build(BuildContext context) {
    final today = todayKey();
    final lastWeek = weekStartOf(today);
    final firstWeek = lastWeek - 7 * (weeks - 1);
    final colW = cell + gap;

    final monthLabels = <Widget>[];
    final columns = <Widget>[];
    int? prevMonth;
    for (var c = 0; c < weeks; c++) {
      final ws = firstWeek + 7 * c;
      final m = dayDate(ws).month;
      final show = prevMonth == null ? dayDate(ws).day <= 7 : m != prevMonth;
      prevMonth = m;
      monthLabels.add(SizedBox(
        width: colW,
        height: _labelH,
        child: show
            ? OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: 40,
                child: Text(monthShort[m - 1], style: ui(10, color: AppColors.muted)),
              )
            : null,
      ));
      columns.add(Padding(
        padding: EdgeInsets.only(right: gap),
        child: Column(
          children: [
            for (var r = 0; r < 7; r++)
              Padding(
                padding: EdgeInsets.only(bottom: r == 6 ? 0 : gap),
                child: _cell(ws + r, today),
              ),
          ],
        ),
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _labelH, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var r = 0; r < 7; r++)
                SizedBox(
                  height: cell + (r == 6 ? 0 : gap),
                  child: Text(
                    r.isEven ? weekdayShort[r].substring(0, 1) : '',
                    style: ui(9.5, color: AppColors.faint, height: 1.2),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: monthLabels),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cell(int day, int today) {
    if (day > today) return SizedBox(width: cell, height: cell);
    final v = valueFor(day);
    final Color fill;
    if (v <= 0 && (missedFor?.call(day) ?? false)) {
      fill = Color.lerp(AppColors.empty, AppColors.danger, 0.55)!;
    } else if (v < 0) {
      fill = AppColors.empty.withValues(alpha: 0.45);
    } else if (v <= 0) {
      fill = AppColors.empty;
    } else {
      final a = v >= 0.999 ? 1.0 : v >= 0.66 ? 0.72 : v >= 0.33 ? 0.48 : 0.28;
      fill = Color.lerp(AppColors.empty, color, a)!;
    }
    final box = Container(
      width: cell,
      height: cell,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(3.5),
        border: day == today ? Border.all(color: AppColors.text.withValues(alpha: 0.75), width: 1.2) : null,
        boxShadow: v >= 0.999 ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)] : null,
      ),
    );
    if (onTap == null) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap!(day), child: box);
  }
}

class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget sq(double a) => Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: a == 0 ? AppColors.empty : Color.lerp(AppColors.empty, color, a),
            borderRadius: BorderRadius.circular(2.5),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: ui(10, color: AppColors.faint)),
        const SizedBox(width: 3),
        sq(0),
        sq(0.28),
        sq(0.48),
        sq(0.72),
        sq(1),
        const SizedBox(width: 6),
        Text('More', style: ui(10, color: AppColors.faint)),
      ],
    );
  }
}
