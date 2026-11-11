import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notifications.dart';
import 'sfx.dart';
import 'widgets/character.dart';
import 'screens/character_screen.dart';
import 'screens/home_screen.dart';
import 'store.dart';
import 'theme.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();
final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await Reminders.init();
  final store = AppStore();
  await store.load();
  store.onLevelUp = (from, to) {
    final fresh = store.settings.unlockAll ? <Alien>[] : aliens.where((a) => a.level > from && a.level <= to).toList();
    Future.delayed(const Duration(milliseconds: 350), () {
      Sfx.play(fresh.isEmpty ? 'levelup' : 'unlock');
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(fresh.isEmpty ? "Level up! You're Lv $to" : 'New alien unlocked: ${fresh.last.name}'),
          action: fresh.isEmpty
              ? null
              : SnackBarAction(
                  label: 'Meet',
                  onPressed: () => navigatorKey.currentState?.pushNamed('/companion'),
                ),
        ));
    });
  };

  runApp(StoreScope(store: store, child: const EmberApp()));

  Reminders.reschedule(store);
  if (store.settings.reminderOn) Reminders.requestPermission();
}

class EmberApp extends StatefulWidget {
  const EmberApp({super.key});

  @override
  State<EmberApp> createState() => _EmberAppState();
}

class _EmberAppState extends State<EmberApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after midnight should roll "today" over and re-plan reminders.
    if (state == AppLifecycleState.resumed) StoreScope.read(context).refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ember',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      navigatorKey: navigatorKey,
      routes: {'/companion': (_) => const CharacterScreen()},
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
