import 'dart:math';

import 'package:flutter/material.dart';

import '../lessons/exercises.dart';
import '../state/app_state.dart';
import 'exercise_view.dart';
import 'lesson_screen.dart';
import 'study_screen.dart';
import 'theme.dart';
import 'word_card.dart';
import 'writing_screen.dart';

/// Главный экран: иероглиф дня, план на сегодня и дополнительные занятия.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.state});
  final AppState state;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final word = state.wordOfTheDay(now);
    final queue = state.sessionQueue(now);
    final t = Theme.of(context).textTheme;
    final next = state.nextLesson;

    final lessonDone = state.lessonDoneToday || next == null;
    final reviewDone = queue.isEmpty;
    final hwDone = state.homeworkChars.isEmpty || state.homeworkComplete;
    final planDone = lessonDone && reviewDone && hwDone;

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
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('План на сегодня', style: t.titleMedium)),
            Icon(Icons.local_fire_department_rounded,
                color: Palette.cinnabar, size: 20),
            Text(' ${state.streak} дн.', style: t.bodyMedium),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              _PlanItem(
                done: lessonDone,
                icon: Icons.school_outlined,
                title: next == null
                    ? 'Все уроки пройдены'
                    : lessonDone
                        ? 'Урок дня пройден'
                        : 'Урок ${next.id}: ${next.title}',
                subtitle: lessonDone ? null : 'Обязательно · около 15 минут',
                onTap: lessonDone
                    ? null
                    : () => _push(
                        context, LessonScreen(state: state, lesson: next)),
              ),
              const Divider(height: 1),
              _PlanItem(
                done: reviewDone,
                icon: Icons.replay_rounded,
                title: reviewDone
                    ? 'Повторение на сегодня сделано'
                    : 'Повторение · ${queue.length} карточек',
                subtitle: reviewDone
                    ? null
                    : 'Слова, которые пора освежить, и новые',
                onTap: reviewDone
                    ? null
                    : () => _push(context, StudyScreen(state: state)),
              ),
              if (state.homeworkChars.isNotEmpty) ...[
                const Divider(height: 1),
                _PlanItem(
                  done: hwDone,
                  icon: Icons.edit_outlined,
                  title: hwDone
                      ? 'Домашнее задание выполнено'
                      : 'Домашнее задание: прописи',
                  subtitle: hwDone
                      ? null
                      : '${state.homeworkChars.join(' ')} · каждый ${state.homeworkRepeats} раза',
                  onTap: hwDone
                      ? null
                      : () => _push(
                          context,
                          WritingScreen(
                            state: state,
                            chars: state.homeworkChars,
                            repeats: state.homeworkRepeats,
                            homework: true,
                          )),
                ),
              ],
            ],
          ),
        ),
        if (planDone) ...[
          const SizedBox(height: 12),
          Text('План выполнен! 加油！ Всё ниже по желанию, для тех, кто хочет быстрее.',
              style: t.bodyMedium?.copyWith(color: Palette.jade)),
        ],
        const SizedBox(height: 20),
        Text('Дополнительно', style: t.titleMedium),
        const SizedBox(height: 8),
        _ExtraGrid(children: [
          if (next != null && lessonDone)
            _Extra(Icons.school_outlined, 'Следующий урок', next.title,
                () => _push(context, LessonScreen(state: state, lesson: next))),
          _Extra(Icons.add_circle_outline, 'Ещё 5 новых слов',
              'сверх дневного лимита', () {
            state.addExtraNew(5);
            _push(context, StudyScreen(state: state));
          }),
          if (state.learnedWords.length >= 4)
            _Extra(Icons.shuffle_rounded, 'Повторить изученное',
                '20 случайных слов', () {
              final ws = [...state.learnedWords]..shuffle();
              _push(context,
                  StudyScreen(state: state, practice: ws.take(20).toList()));
            }),
          if (state.learnedWords.length >= 4)
            _Extra(Icons.graphic_eq_rounded, 'Тренировка тонов',
                'выберите правильное чтение', () => _tones(context)),
          if (state.learnedWords.isNotEmpty)
            _Extra(Icons.draw_outlined, 'Прописи', 'изученные иероглифы', () {
              final chars = <String>{
                for (final w in state.learnedWords) ...w.hanzi.split('')
              }.toList()
                ..shuffle();
              _push(context,
                  WritingScreen(state: state, chars: chars.take(5).toList(), repeats: 2));
            }),
        ]),
      ],
    );
  }

  void _tones(BuildContext context) {
    final rnd = Random();
    final ws = [...state.learnedWords]..shuffle(rnd);
    final ex = <Exercise>[];
    for (final w in ws) {
      if (ex.length >= 10) break;
      final v = toneVariants(w.pinyin, rnd);
      if (v.length >= 2) ex.add(ChooseTone(w, [w.pinyin, ...v]..shuffle(rnd)));
    }
    if (ex.isEmpty) return;
    _push(
      context,
      Scaffold(
        appBar: AppBar(title: const Text('Тренировка тонов')),
        body: SafeArea(
          child: Builder(
            builder: (ctx) => ExerciseRunner(
              exercises: ex,
              onFinished: (ok, total) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Тоны: $ok из $total с первой попытки')));
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanItem extends StatelessWidget {
  const _PlanItem(
      {required this.done,
      required this.icon,
      required this.title,
      this.subtitle,
      this.onTap});
  final bool done;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor:
              done ? Palette.jade : Palette.cinnabar.withValues(alpha: 0.12),
          foregroundColor: done ? Colors.white : Palette.cinnabar,
          child: Icon(done ? Icons.check_rounded : icon),
        ),
        title: Text(title,
            style: done
                ? TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)
                : null),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      );
}

class _Extra {
  const _Extra(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ExtraGrid extends StatelessWidget {
  const _ExtraGrid({required this.children});
  final List<_Extra> children;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final e in children)
            SizedBox(
              width: w,
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: e.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(e.icon, color: Palette.cinnabar),
                        const SizedBox(height: 8),
                        Text(e.title, style: t.titleSmall),
                        Text(e.subtitle,
                            style: t.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
