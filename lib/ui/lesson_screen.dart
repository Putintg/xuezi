import 'package:flutter/material.dart';

import '../lessons/exercises.dart';
import '../lessons/lesson.dart';
import '../services/speech.dart';
import '../state/app_state.dart';
import 'exercise_view.dart';
import 'theme.dart';
import 'word_card.dart';

/// Урок по шагам: слова → грамматика → диалог → упражнения → итог.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.state, required this.lesson});
  final AppState state;
  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  static const _steps = ['Слова', 'Грамматика', 'Диалог', 'Упражнения'];
  int _step = 0;
  int? _score;
  int _total = 0;

  void _next() => setState(() => _step++);

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: i <= _step
                                ? Palette.cinnabar
                                : Palette.cinnabar.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_steps[i],
                            style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(child: _body(l)),
    );
  }

  Widget _body(Lesson l) {
    final words = widget.state.lessonWords(l);
    switch (_step) {
      case 0:
        return _Scrolled(
          onNext: _next,
          children: [
            Text(l.goal, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            for (final w in words)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: SizedBox(
                    width: 64,
                    child: Text(w.hanzi,
                        textAlign: TextAlign.center,
                        style: hanziStyle(w.hanzi.length > 2 ? 22 : 30)),
                  ),
                  title: Text(w.pinyin,
                      style: const TextStyle(color: Palette.cinnabar)),
                  subtitle: Text(w.meaning),
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => Speech.say(w.hanzi),
                  ),
                  onTap: w.id >= 0 ? () => showWordSheet(context, w) : null,
                ),
              ),
          ],
        );
      case 1:
        return _Scrolled(
          onNext: _next,
          children: [for (final g in l.grammar) _GrammarCard(g)],
        );
      case 2:
        return _Scrolled(
          onNext: _next,
          children: [
            Text(l.dialogueTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Коснитесь фразы, чтобы увидеть пиньинь и перевод',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            for (final s in l.dialogue) _DialogueLine(s),
          ],
        );
      case 3:
        return ExerciseRunner(
          exercises: buildExercises(l, words, widget.state.studyPool),
          onFinished: (correct, total) => setState(() {
            _score = correct;
            _total = total;
            _step = 4;
          }),
        );
      default:
        return _finish(l);
    }
  }

  Widget _finish(Lesson l) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Text('棒!', style: hanziStyle(80, color: Palette.cinnabar)),
          const SizedBox(height: 12),
          Text('Урок «${l.title}» пройден', style: t.titleLarge),
          const SizedBox(height: 8),
          Text('С первой попытки: $_score из $_total', style: t.bodyLarge),
          if (l.culture.isNotEmpty) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Palette.jade),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.culture, style: t.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          Text('Слова урока добавлены в повторение и на экран блокировки.',
              textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            onPressed: () async {
              await widget.state.completeLesson(l);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Завершить урок'),
          ),
        ],
      ),
    );
  }
}

class _Scrolled extends StatelessWidget {
  const _Scrolled({required this.children, required this.onNext});
  final List<Widget> children;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: onNext,
              child: const Text('Дальше'),
            ),
          ),
        ],
      );
}

class _GrammarCard extends StatelessWidget {
  const _GrammarCard(this.g);
  final GrammarPoint g;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.title, style: t.titleMedium),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Palette.cinnabar.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(g.pattern,
                  style: hanziStyle(18, color: Palette.cinnabar)),
            ),
            const SizedBox(height: 10),
            Text(g.explanation, style: t.bodyMedium),
            const SizedBox(height: 8),
            for (final e in g.examples)
              InkWell(
                onTap: () => Speech.say(e.zh),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.zh, style: hanziStyle(20)),
                      Text(e.py,
                          style: t.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      Text(e.ru, style: t.bodyMedium),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DialogueLine extends StatefulWidget {
  const _DialogueLine(this.s);
  final Sentence s;

  @override
  State<_DialogueLine> createState() => _DialogueLineState();
}

class _DialogueLineState extends State<_DialogueLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final isA = s.who != 'B';
    final t = Theme.of(context).textTheme;
    final bubble = isA
        ? Theme.of(context).cardTheme.color
        : Palette.jade.withValues(alpha: 0.12);
    return Align(
      alignment: isA ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: GestureDetector(
          onTap: () {
            setState(() => _open = !_open);
            if (_open) Speech.say(s.zh);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: bubble,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.zh, style: hanziStyle(20)),
                if (_open) ...[
                  const SizedBox(height: 2),
                  Text(s.py,
                      style: t.bodySmall?.copyWith(color: Palette.cinnabar)),
                  Text(s.ru, style: t.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
