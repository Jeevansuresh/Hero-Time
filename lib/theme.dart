import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Omnitrix palette, sampled from the watch face: deep black, steel, watch green
/// and the lime of the hourglass.
class AppColors {
  static const bg = Color(0xFF030504);
  static const card = Color(0xFF0A0F0C);
  static const cardHi = Color(0xFF111814);
  static const border = Color(0xFF1B2620);
  static const empty = Color(0xFF151E18);
  static const text = Color(0xFFF2F6EF);
  static const muted = Color(0xFF8E9C92);
  static const faint = Color(0xFF55625A);
  static const danger = Color(0xFFFF5A5A);
  static const green = Color(0xFFC0D72D); // hourglass lime (primary accent)
  static const watch = Color(0xFF4CBF45); // bezel green
  static const steel = Color(0xFF7E858B);
}

/// Habit colours. Later ones unlock as you level up.
const habitPalette = <int>[
  0xFFC0D72D, // hourglass lime
  0xFF4CBF45, // watch green
  0xFFFF6A1A, // heatblast
  0xFF3FA9FF, // xlr8
  0xFFFF4D4D, // four arms
  0xFF3BE3B8, // diamondhead
  0xFFFF9F43, // wildmutt
  0xFF5FB2D9, // ripjaws
  0xFFCFC8FF, // ghostfreak
  0xFFF2F6EF, // white
];
const paletteUnlockLevel = <int>[1, 1, 1, 1, 1, 3, 5, 8, 12, 16];

TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color color = AppColors.text}) =>
    GoogleFonts.orbitron(fontSize: size * 0.82, fontWeight: weight, color: color, letterSpacing: 0.4, height: 1.15);

TextStyle ui(double size,
        {FontWeight weight = FontWeight.w500, Color color = AppColors.text, double? height, double? spacing}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

/// Small uppercase tracking label (the "eyebrow" above numbers and sections).
TextStyle eyebrow({Color color = AppColors.muted, double size = 10.5}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w600, color: color, letterSpacing: 1.6);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.green,
      onPrimary: Color(0xFF0B0F05),
      secondary: AppColors.watch,
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    splashFactory: InkSparkle.splashFactory,
    iconTheme: const IconThemeData(color: AppColors.muted),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? const Color(0xFF0B0F05) : AppColors.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.green : AppColors.empty),
      trackOutlineColor: WidgetStateProperty.all(AppColors.border),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cardHi,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(surfaceTintColor: Colors.transparent, dragHandleColor: AppColors.faint),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: AppColors.cardHi,
      dialHandColor: AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cardHi,
      contentTextStyle: ui(14, weight: FontWeight.w600),
      actionTextColor: AppColors.green,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.green.withValues(alpha: 0.35)),
      ),
    ),
  );
}

AppBar flatAppBar(String title, {List<Widget>? actions, Widget? titleWidget}) => AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.text),
      titleSpacing: 4,
      title: titleWidget ?? Text(title, style: heading(19)),
      actions: actions,
    );

InputDecoration fieldDeco({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: ui(15, color: AppColors.faint),
      filled: true,
      fillColor: AppColors.cardHi,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.7), width: 1.2),
      ),
    );

/// Scaffold with the app's backdrop: a soft lime glow at the top and a faint tech grid.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, this.appBar, this.body});
  final PreferredSizeWidget? appBar;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: appBar,
      extendBodyBehindAppBar: false,
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: Backdrop())),
          if (body != null) Positioned.fill(child: body!),
        ],
      ),
    );
  }
}

class Backdrop extends StatelessWidget {
  const Backdrop({super.key});

  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: _BackdropPainter()));
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Top glow
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -1.15),
          radius: 1.1,
          colors: [AppColors.watch.withValues(alpha: 0.16), AppColors.green.withValues(alpha: 0.03), Colors.transparent],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    // Faint grid that fades out downwards
    const step = 28.0;
    final fade = (double y) => (1 - y / (size.height * 0.55)).clamp(0.0, 1.0);
    for (double y = 0; y < size.height * 0.55; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          Paint()..color = AppColors.green.withValues(alpha: 0.035 * fade(y)));
    }
    for (double x = (size.width % step) / 2; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height * 0.55),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.green.withValues(alpha: 0.035), Colors.transparent],
          ).createShader(Rect.fromLTWH(x, 0, 1, size.height * 0.55)),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => false;
}

/// Glass card: soft vertical gradient, hairline border that catches light at the top,
/// and an optional coloured glow.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.glow, this.radius = 24});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? glow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0.03)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 30, offset: const Offset(0, 14)),
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.16), blurRadius: 40, spreadRadius: -6),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: Material(
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(radius - 1),
        color: Colors.transparent,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.cardHi, AppColors.card],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.green.withValues(alpha: 0.08),
            highlightColor: Colors.white.withValues(alpha: 0.02),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12, left: 4, right: 4),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 2,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: AppColors.green.withValues(alpha: 0.7), blurRadius: 6)],
            ),
          ),
          Text(text.toUpperCase(), style: eyebrow(size: 11, color: AppColors.text.withValues(alpha: 0.75))),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. "LV 4" or a species name.
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.color = AppColors.green, this.filled = false});
  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.35)),
        ),
        child: Text(text.toUpperCase(),
            style: eyebrow(size: 9.5, color: filled ? const Color(0xFF0B0F05) : color).copyWith(fontWeight: FontWeight.w700)),
      );
}

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.empty,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.03, 1.0),
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [Color.lerp(color, Colors.black, 0.15)!, Color.lerp(color, Colors.white, 0.3)!]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 10)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Omnitrix face (assets/brand/omnitrix.png) with an optional glow.
class OmnitrixLogo extends StatelessWidget {
  const OmnitrixLogo({super.key, this.size = 44, this.glow = true, this.opacity = 1});
  final double size;
  final bool glow;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glow ? [BoxShadow(color: AppColors.green.withValues(alpha: 0.35), blurRadius: size * 0.45)] : null,
        ),
        child: Opacity(
          opacity: opacity,
          child: Image.asset('assets/brand/omnitrix.png', width: size, height: size, filterQuality: FilterQuality.medium),
        ),
      );
}

Future<String?> promptText(BuildContext context,
    {required String title, String initial = '', String? hint, int maxLines = 1, String action = 'Save'}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: heading(19)),
      content: TextField(
        controller: c,
        autofocus: true,
        maxLines: maxLines,
        minLines: 1,
        style: ui(15),
        decoration: fieldDeco(hint: hint).copyWith(fillColor: AppColors.card),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: ui(14, color: AppColors.muted))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: Text(action, style: ui(14, weight: FontWeight.w700, color: AppColors.green))),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, {required String title, required String body, String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: heading(19)),
      content: Text(body, style: ui(14, color: AppColors.muted, height: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: ui(14, color: AppColors.muted))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: ui(14, weight: FontWeight.w700, color: AppColors.danger))),
      ],
    ),
  );
  return ok ?? false;
}
