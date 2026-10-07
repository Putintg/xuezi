import 'package:flutter/material.dart';

import 'services/lockscreen.dart';
import 'state/app_state.dart';
import 'ui/dictionary_screen.dart';
import 'ui/onboarding_screen.dart';
import 'ui/progress_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/theme.dart';
import 'ui/today_screen.dart';
import 'ui/word_card.dart';

final _navigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  await Lockscreen.init();
  state.onLockscreenDataChanged = () => Lockscreen.refresh(state);
  Lockscreen.onOpenWord = (id) {
    final ctx = _navigator.currentContext;
    if (ctx != null && id < state.words.length) {
      showWordSheet(ctx, state.words[id]);
    }
  };
  runApp(XueziApp(state: state));
  if (state.onboarded) Lockscreen.refresh(state);
}

class XueziApp extends StatelessWidget {
  const XueziApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сюэцзы',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: ListenableBuilder(
        listenable: state,
        builder: (context, _) => state.onboarded
            ? HomeShell(state: state)
            : OnboardingScreen(state: state),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

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
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Новый день или наступившие повторения — обновить экран и расписание.
    if (s == AppLifecycleState.resumed) {
      setState(() {});
      Lockscreen.refresh(widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Сегодня', 'Словарь', 'Прогресс'];
    final pages = [
      TodayScreen(state: widget.state),
      DictionaryScreen(state: widget.state),
      ProgressScreen(state: widget.state),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(state: widget.state))),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined), label: 'Сегодня'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'Словарь'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: 'Прогресс'),
        ],
      ),
    );
  }
}
