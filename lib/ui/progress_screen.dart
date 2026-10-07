import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'theme.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mature = state.cards.values.where((c) => c.isMature).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _big(context, '${state.streak}', 'дней подряд',
                Icons.local_fire_department_rounded, Palette.cinnabar),
            const SizedBox(width: 12),
            _big(context, '${state.learnedTotal}', 'слов начато',
                Icons.school_rounded, Palette.level(2)),
            const SizedBox(width: 12),
            _big(context, '$mature', 'закреплено',
                Icons.verified_rounded, Palette.jade),
          ],
        ),
        const SizedBox(height: 24),
        Text('Уровни HSK', style: t.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var l = 1; l <= 4; l++) _levelBar(context, l),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Последние 4 недели', style: t.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _calendar(context),
          ),
        ),
      ],
    );
  }

  Widget _big(BuildContext context, String v, String label, IconData icon,
          Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(v, style: Theme.of(context).textTheme.headlineSmall),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );

  Widget _levelBar(BuildContext context, int l) {
    final done = state.learnedInLevel(l);
    final total = state.totalInLevel(l);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text('HSK $l')),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: total == 0 ? 0 : done / total,
                color: Palette.level(l),
                backgroundColor: Palette.level(l).withValues(alpha: 0.12),
              ),
            ),
          ),
          SizedBox(
              width: 72,
              child: Text('$done / $total', textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _calendar(BuildContext context) {
    final today = DateTime.now();
    final days = [
      for (var i = 27; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i)
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in days)
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: state.studyDays.contains(dayKey(d))
                  ? Palette.jade
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${d.day}',
                style: TextStyle(
                    fontSize: 12,
                    color: state.studyDays.contains(dayKey(d))
                        ? Colors.white
                        : null)),
          ),
      ],
    );
  }
}
