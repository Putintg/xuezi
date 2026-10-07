import 'package:flutter/material.dart';

import '../services/lockscreen.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;

  static const intervals = {
    30: 'каждые 30 минут',
    60: 'каждый час',
    120: 'каждые 2 часа',
    180: 'каждые 3 часа',
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(
          children: [
            const _Header('Учёба'),
            ListTile(
              title: const Text('Уровни HSK'),
              subtitle: Wrap(
                spacing: 8,
                children: [
                  for (var l = 1; l <= 6; l++)
                    FilterChip(
                      label: Text('HSK $l'),
                      selected: state.levels.contains(l),
                      onSelected: (on) {
                        final s = {...state.levels};
                        on ? s.add(l) : s.remove(l);
                        state.updateSettings(levels: s);
                      },
                    ),
                ],
              ),
            ),
            ListTile(
              title: Text('Новых слов в день: ${state.dailyNew}'),
              subtitle: Slider(
                min: 1,
                max: 30,
                divisions: 29,
                value: state.dailyNew.toDouble(),
                onChanged: (v) => state.updateSettings(dailyNew: v.round()),
              ),
            ),
            const _Header('Экран блокировки'),
            SwitchListTile(
              title: const Text('Показывать слова на экране блокировки'),
              subtitle: const Text(
                  'Уведомление с новым словом приходит по расписанию'),
              value: state.lockEnabled,
              onChanged: (v) async {
                if (v) await Lockscreen.requestPermission();
                state.updateSettings(lockEnabled: v);
              },
            ),
            ListTile(
              enabled: state.lockEnabled,
              title: const Text('Как часто'),
              trailing: DropdownButton<int>(
                value: state.lockEveryMinutes,
                onChanged: state.lockEnabled
                    ? (v) => state.updateSettings(lockEveryMinutes: v)
                    : null,
                items: [
                  for (final e in intervals.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
              ),
            ),
            ListTile(
              enabled: state.lockEnabled,
              title: Text(
                  'С ${state.lockStartHour}:00 до ${state.lockEndHour}:00'),
              subtitle: RangeSlider(
                min: 0,
                max: 23,
                divisions: 23,
                values: RangeValues(state.lockStartHour.toDouble(),
                    state.lockEndHour.toDouble()),
                onChanged: state.lockEnabled
                    ? (r) => state.updateSettings(
                        lockStartHour: r.start.round(),
                        lockEndHour: r.end.round())
                    : null,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Показать слово сейчас'),
              subtitle: const Text('Проверить, как выглядит уведомление'),
              onTap: () async {
                await Lockscreen.requestPermission();
                await Lockscreen.showNow(state.wordOfTheDay(DateTime.now()));
              },
            ),
            const ListTile(
              leading: Icon(Icons.widgets_outlined),
              title: Text('Виджет на главный экран'),
              subtitle: Text(
                  'Удерживайте палец на пустом месте рабочего стола, выберите «Виджеты» и найдите «Сюэцзы». '
                  'Слово в виджете меняется с той же частотой, что и уведомления.'),
            ),
            const _Header('О приложении'),
            const ListTile(
              title: Text('Источники данных'),
              subtitle: Text(
                  'Списки слов HSK: complete-hsk-vocabulary (MIT). '
                  'Английские значения: CC-CEDICT (CC BY-SA 4.0). '
                  'Русские переводы и примеры написаны для этого приложения.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
