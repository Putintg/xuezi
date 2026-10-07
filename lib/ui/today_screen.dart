import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'study_screen.dart';
import 'theme.dart';
import 'word_card.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final word = state.wordOfTheDay(now);
    final queue = state.sessionQueue(now);
    final due = state.dueWords(now).length;
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('Иероглиф дня', style: t.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: TapRevealCard(word),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Stat(
                icon: Icons.local_fire_department_rounded,
                color: Palette.cinnabar,
                value: '${state.streak}',
                label: 'дней подряд'),
            const SizedBox(width: 12),
            _Stat(
                icon: Icons.replay_rounded,
                color: Palette.jade,
                value: '$due',
                label: 'на повтор'),
            const SizedBox(width: 12),
            _Stat(
                icon: Icons.add_rounded,
                color: Palette.level(2),
                value: '${state.newLeftToday}',
                label: 'новых'),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: t.titleMedium),
          onPressed: queue.isEmpty
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => StudyScreen(state: state))),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(queue.isEmpty
              ? 'На сегодня всё выучено'
              : 'Начать занятие · ${queue.length}'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
