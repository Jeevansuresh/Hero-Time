import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../analytics.dart';
import '../store.dart';
import '../theme.dart';
import 'analytics_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';

/// Home · Analytics · Insights · Settings, with a slim floating tab bar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  static void goTo(BuildContext context, int tab) => context.findAncestorStateOfType<_RootShellState>()?._go(tab);

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  void _go(int i) {
    if (i == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final alert = s.habits.isNotEmpty && Analytics(s).biggestRisk != null;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: const [HomeScreen(), AnalyticsScreen(), InsightsScreen(), SettingsScreen(inTab: true)],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12 + MediaQuery.of(context).padding.bottom,
            child: Center(child: _TabBar(index: _tab, alert: alert, onTap: _go)),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.alert, required this.onTap});
  final int index;
  final bool alert;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'HOME'),
    (Icons.bar_chart_rounded, Icons.bar_chart_rounded, 'ANALYTICS'),
    (Icons.hourglass_empty_rounded, Icons.hourglass_full_rounded, 'INSIGHTS'),
    (Icons.settings_outlined, Icons.settings_rounded, 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xE60A0F0C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF26342C)),
          boxShadow: const [BoxShadow(color: Color(0x8C000000), blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(0, 7, 0, 5),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.green.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(i == index ? _items[i].$2 : _items[i].$1,
                                size: 20,
                                color: i == index ? AppColors.green : AppColors.faint,
                                shadows: i == index ? [Shadow(color: AppColors.green.withValues(alpha: 0.6), blurRadius: 8)] : null),
                            if (i == 2 && alert)
                              Positioned(
                                right: -3,
                                top: -1,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(_items[i].$3,
                            style: eyebrow(size: 8.5, color: i == index ? AppColors.green : AppColors.faint)
                                .copyWith(fontWeight: FontWeight.w700, letterSpacing: .8)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
