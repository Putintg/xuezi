import 'package:flutter/material.dart';

import '../services/lockscreen.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// Первый запуск: уровень, темп и разрешение на уведомления.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  int _level = 1;
  int _perDay = 5;

  static const _levelHints = {
    1: 'Начинаю с нуля',
    2: 'Знаю пару сотен слов',
    3: 'Читаю простые тексты',
    4: 'Уверенный средний уровень',
  };

  void _next() => _pages.nextPage(
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  Future<void> _finish() async {
    await Lockscreen.requestPermission();
    // Выбранный уровень и все уровни ниже — чтобы не пропустить базу.
    await widget.state.completeOnboarding(
        {for (var l = 1; l <= _level; l++) l}, _perDay);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _welcome(t),
                  _levelPage(t),
                  _pacePage(t),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56)),
                onPressed: _page < 2 ? _next : _finish,
                child: Text(_page < 2 ? 'Далее' : 'Начать'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(TextTheme t) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('学字', style: hanziStyle(96, color: Palette.cinnabar)),
            const SizedBox(height: 16),
            Text('Сюэцзы', style: t.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Учите иероглифы каждый день, не открывая приложение: '
              'новые слова появляются на экране блокировки и в виджете, '
              'а повторения приходят ровно тогда, когда вы начинаете забывать.',
              textAlign: TextAlign.center,
              style: t.bodyLarge,
            ),
          ],
        ),
      );

  Widget _levelPage(TextTheme t) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Какой у вас уровень?', style: t.headlineSmall),
          const SizedBox(height: 16),
          for (var l = 1; l <= 4; l++)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: _level == l
                        ? Palette.level(l)
                        : Colors.transparent,
                    width: 2),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: Palette.level(l),
                  foregroundColor: Colors.white,
                  child: Text('$l'),
                ),
                title: Text('HSK $l'),
                subtitle: Text(_levelHints[l]!),
                onTap: () => setState(() => _level = l),
              ),
            ),
        ],
      );

  Widget _pacePage(TextTheme t) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сколько новых слов в день?', style: t.headlineSmall),
            const SizedBox(height: 32),
            Center(
                child: Text('$_perDay',
                    style: t.displayLarge?.copyWith(color: Palette.cinnabar))),
            Slider(
              min: 1,
              max: 30,
              divisions: 29,
              value: _perDay.toDouble(),
              onChanged: (v) => setState(() => _perDay = v.round()),
            ),
            const SizedBox(height: 8),
            Text(
              'Примерно ${_perDay * 2} минут в день. '
              'Уровень HSK $_level займёт около '
              '${(widget.state.words.where((w) => w.level <= _level).length / _perDay).ceil()} дней.',
              style: t.bodyLarge,
            ),
            const Spacer(),
            Text(
              'Дальше приложение попросит разрешение на уведомления: '
              'через них слова появляются на экране блокировки.',
              style: t.bodyMedium,
            ),
          ],
        ),
      );
}
