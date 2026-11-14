import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../notifications.dart';
import '../sfx.dart';
import '../store.dart';
import '../theme.dart';
import 'lobby_music_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final st = s.settings;
    final time = TimeOfDay(hour: st.hour, minute: st.minute);

    void toast(String m) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));

    return AppScaffold(
      appBar: flatAppBar('Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        children: [
          const SectionLabel('Reminder'),
          _Group(children: [
            _Switch(
              title: 'Daily reminder',
              subtitle: 'One nudge a day to log',
              value: st.reminderOn,
              onChanged: (v) async {
                if (v) await Reminders.requestPermission();
                s.updateSettings((x) => x.reminderOn = v);
              },
            ),
            _Tile(
              title: 'Time',
              enabled: st.reminderOn,
              trailing: Text(time.format(context), style: ui(15, weight: FontWeight.w700, color: AppColors.green)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: time);
                if (picked != null) {
                  s.updateSettings((x) {
                    x.hour = picked.hour;
                    x.minute = picked.minute;
                  });
                }
              },
            ),
            _Switch(
              title: 'Skip if already logged',
              subtitle: 'No ping on days you\'ve logged everything',
              value: st.skipIfLogged,
              onChanged: st.reminderOn ? (v) => s.updateSettings((x) => x.skipIfLogged = v) : null,
            ),
            _Tile(
              title: 'Send a test notification',
              trailing: const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.muted),
              onTap: () async {
                await Reminders.requestPermission();
                await Reminders.showTest(st.petName);
              },
            ),
          ]),
          const SectionLabel('Customise'),
          _Group(children: [
            _Tile(
              title: 'Hero name',
              trailing: Text(st.petName, style: ui(14, color: AppColors.muted)),
              onTap: () async {
                final n = await promptText(context, title: 'Name your hero', initial: st.petName);
                if (n != null && n.trim().isNotEmpty) s.updateSettings((x) => x.petName = n.trim());
              },
            ),
            _Switch(
              title: 'Sound effects',
              subtitle: 'Ticks, level-ups, unlocks and transforms',
              value: st.sound,
              onChanged: (v) {
                s.updateSettings((x) => x.sound = v);
                if (v) Sfx.play('check');
              },
            ),
            _Tile(
              title: 'Lobby music',
              subtitle: st.music ? s.selectedTrack.name : 'Off',
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyMusicScreen())),
            ),
            _Switch(
              title: 'Unlock everything',
              subtitle: 'Skip level gates for DNA, mission slots and colours',
              value: st.unlockAll,
              onChanged: (v) => s.updateSettings((x) => x.unlockAll = v),
            ),
          ]),
          const SectionLabel('Data'),
          _Group(children: [
            _Tile(
              title: 'Export backup',
              subtitle: 'Copies everything as JSON to the clipboard',
              trailing: const Icon(Icons.copy_rounded, size: 19, color: AppColors.muted),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: s.exportJson()));
                toast('Backup copied. Paste it somewhere safe.');
              },
            ),
            _Tile(
              title: 'Import backup',
              subtitle: 'Replaces current data',
              trailing: const Icon(Icons.download_rounded, size: 19, color: AppColors.muted),
              onTap: () async {
                final clip = await Clipboard.getData(Clipboard.kTextPlain);
                if (!context.mounted) return;
                final raw = await promptText(
                  context,
                  title: 'Paste backup JSON',
                  initial: clip?.text ?? '',
                  maxLines: 6,
                  action: 'Import',
                );
                if (raw == null || raw.trim().isEmpty) return;
                toast(s.importJson(raw) ? 'Backup restored' : "That doesn't look like a Hero Time backup");
              },
            ),
            _Tile(
              title: 'Reset everything',
              danger: true,
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: 'Reset everything?',
                  body: 'All habits, logs and XP will be erased. Export a backup first if you might want it.',
                  action: 'Reset',
                );
                if (ok) s.resetAll();
              },
            ),
          ]),
          const SizedBox(height: 28),
          Center(child: OmnitrixLogo(size: 40, opacity: 0.9)),
          const SizedBox(height: 12),
          Center(child: Text('HERO TIME', style: heading(13, color: AppColors.muted).copyWith(letterSpacing: 3))),
          const SizedBox(height: 4),
          Center(child: Text('Everything stays on this device', style: ui(11.5, color: AppColors.faint))),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.border, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, this.subtitle, this.trailing, this.onTap, this.enabled = true, this.danger = false});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled, danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ui(15, weight: FontWeight.w600, color: danger ? AppColors.danger : AppColors.text)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: ui(12.5, color: AppColors.muted)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.title, required this.value, required this.onChanged, this.subtitle});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return _Tile(
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.green,
      ),
    );
  }
}
