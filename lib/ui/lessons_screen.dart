import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'lesson_screen.dart';
import 'theme.dart';

/// Список уроков: идут по порядку, следующий открывается после предыдущего.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (state.lessons.isEmpty) {
      return const Center(child: Text('Уроки скоро появятся'));
    }
    final done = state.lessons
        .where((l) => state.completedLessons.contains(l.key))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('HSK 1 · пройдено $done из ${state.lessons.length}',
            style: t.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: done / state.lessons.length,
            color: Palette.jade,
            backgroundColor: Palette.jade.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 16),
        for (final l in state.lessons)
          Builder(builder: (context) {
            final completed = state.completedLessons.contains(l.key);
            final open = state.isLessonOpen(l);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                enabled: open,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: completed
                      ? Palette.jade
                      : open
                          ? Palette.cinnabar
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                  foregroundColor: Colors.white,
                  child: completed
                      ? const Icon(Icons.check_rounded)
                      : open
                          ? Text('${l.id}')
                          : const Icon(Icons.lock_outline_rounded, size: 18),
                ),
                title: Text(l.title, style: t.titleMedium),
                subtitle: Text('${l.titleZh}\n${l.words.length} слов',
                    maxLines: 2),
                isThreeLine: true,
                trailing: open ? const Icon(Icons.chevron_right) : null,
                onTap: open
                    ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LessonScreen(state: state, lesson: l)))
                    : null,
              ),
            );
          }),
      ],
    );
  }
}
