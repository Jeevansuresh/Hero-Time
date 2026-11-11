import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF09090C);
  static const card = Color(0xFF121217);
  static const cardHi = Color(0xFF1A1A21);
  static const border = Color(0xFF212129);
  static const empty = Color(0xFF1D1D25);
  static const text = Color(0xFFF2F2F5);
  static const muted = Color(0xFF8B8B98);
  static const faint = Color(0xFF55555F);
  static const danger = Color(0xFFFF6B6B);
  static const green = Color(0xFF39D353);
}

/// Habit colours. Later ones unlock as the companion levels up.
const habitPalette = <int>[
  0xFF39D353, // GitHub green
  0xFF8B6CFF, // violet
  0xFFFFB020, // amber
  0xFF2FB8FF, // sky
  0xFFFF5C8A, // pink
  0xFF00D1B2, // teal
  0xFFFF7A45, // orange
  0xFFB8E986, // lime
  0xFFE5C07B, // gold
  0xFFF2F2F5, // pearl
];
const paletteUnlockLevel = <int>[1, 1, 1, 1, 1, 3, 5, 8, 12, 16];

TextStyle heading(double size, {FontWeight weight = FontWeight.w700, Color color = AppColors.text}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.4);

TextStyle ui(double size,
        {FontWeight weight = FontWeight.w500, Color color = AppColors.text, double? height, double? spacing}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height, letterSpacing: spacing);

ThemeData buildTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.green,
      secondary: Color(0xFF8B6CFF),
      surface: AppColors.card,
      onSurface: AppColors.text,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    splashFactory: InkRipple.splashFactory,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cardHi,
      contentTextStyle: ui(14),
      actionTextColor: AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

AppBar flatAppBar(String title, {List<Widget>? actions, Widget? titleWidget}) => AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: titleWidget ?? Text(title, style: heading(20)),
      actions: actions,
    );

InputDecoration fieldDeco({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: ui(15, color: AppColors.faint),
      filled: true,
      fillColor: AppColors.cardHi,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.2),
      ),
    );

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
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
      padding: const EdgeInsets.only(top: 26, bottom: 10, left: 2, right: 2),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: ui(11.5, weight: FontWeight.w700, color: AppColors.muted, spacing: 1.4)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.value, required this.color, this.height = 7});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppColors.empty, borderRadius: BorderRadius.circular(height)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.03, 1.0),
          heightFactor: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.35)!]),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> promptText(BuildContext context,
    {required String title, String initial = '', String? hint, int maxLines = 1, String action = 'Save'}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardHi,
      surfaceTintColor: Colors.transparent,
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
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(action, style: ui(14, weight: FontWeight.w700, color: AppColors.green))),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, {required String title, required String body, String action = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardHi,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: heading(19)),
      content: Text(body, style: ui(14, color: AppColors.muted, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: ui(14, color: AppColors.muted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: ui(14, weight: FontWeight.w700, color: AppColors.danger))),
      ],
    ),
  );
  return ok ?? false;
}
