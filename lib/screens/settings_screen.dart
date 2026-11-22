import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../coach.dart';
import '../notifications.dart';
import '../sfx.dart';
import '../store.dart';
import '../theme.dart';
import 'lobby_music_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.inTab = false});

  /// Shown as a tab (no back arrow, room for the tab bar) rather than pushed.
  final bool inTab;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final st = s.settings;
    final time = TimeOfDay(hour: st.hour, minute: st.minute);

    void toast(String m) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));

    return AppScaffold(
      appBar: inTab
          ? flatAppBar('Settings', titleWidget: Text('SETTINGS', style: heading(18).copyWith(letterSpacing: 3)))
          : flatAppBar('Settings'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, inTab ? 110 : 48),
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
            _Tile(
              title: 'Test a reminder in 1 minute',
              subtitle: 'Close the app and wait. If nothing arrives, your phone is blocking reminders',
              trailing: const Icon(Icons.alarm_rounded, size: 20, color: AppColors.muted),
              onTap: () async {
                await Reminders.requestPermission();
                final ok = await Reminders.testInOneMinute(st.petName);
                toast(ok ? 'Scheduled. Close the app; it should arrive in about a minute.' : "Couldn't schedule it. Check notification permission.");
              },
            ),
          ]),
          const SectionLabel('AI coach'),
          const _Group(children: [_ApiKeyTile()]),
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


/// Claude API key: entered here, stored encrypted on this phone, used by Insights.
class _ApiKeyTile extends StatefulWidget {
  const _ApiKeyTile();

  @override
  State<_ApiKeyTile> createState() => _ApiKeyTileState();
}

class _ApiKeyTileState extends State<_ApiKeyTile> {
  String? _key;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    Coach.apiKey().then((k) => mounted ? setState(() => _key = k) : null);
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _edit() async {
    final c = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Claude API key', style: heading(19)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Paste a key from console.anthropic.com. It stays encrypted on this phone and is only sent to Anthropic.',
              style: ui(13, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            style: ui(15),
            decoration: fieldDeco(hint: 'sk-ant-...').copyWith(fillColor: AppColors.card),
          ),
        ]),
        actions: [
          if (_key != null)
            TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text('Remove', style: ui(14, color: AppColors.danger))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: ui(14, color: AppColors.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: Text('Save', style: ui(14, weight: FontWeight.w700, color: AppColors.green))),
        ],
      ),
    );
    if (res == null) return;
    if (res.trim().isEmpty) {
      await Coach.setKey(null);
      setState(() => _key = null);
      _toast('API key removed');
      return;
    }
    setState(() => _testing = true);
    final err = await Coach.test(res.trim());
    if (!mounted) return;
    setState(() => _testing = false);
    if (err != null) {
      _toast(err);
      return;
    }
    await Coach.setKey(res);
    Sfx.play('goal');
    setState(() => _key = res.trim());
    _toast('Connected. Your coach is ready in Insights.');
  }

  @override
  Widget build(BuildContext context) => _Tile(
        title: 'Claude API key',
        subtitle: _key == null ? 'Turns on the weekly debrief in Insights' : 'Stored encrypted on this phone · Claude Haiku',
        trailing: _testing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.green))
            : Text(_key == null ? 'Add' : 'Connected',
                style: ui(14, weight: FontWeight.w700, color: _key == null ? AppColors.muted : AppColors.green)),
        onTap: _testing ? null : _edit,
      );
}
