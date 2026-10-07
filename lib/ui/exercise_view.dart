import 'package:flutter/material.dart';

import '../lessons/exercises.dart';
import '../services/speech.dart';
import 'theme.dart';

/// Проводит упражнения по одному. Ошибочные возвращаются в конец очереди.
class ExerciseRunner extends StatefulWidget {
  const ExerciseRunner(
      {super.key, required this.exercises, required this.onFinished});
  final List<Exercise> exercises;
  final void Function(int correctFirstTry, int total) onFinished;

  @override
  State<ExerciseRunner> createState() => _ExerciseRunnerState();
}

class _ExerciseRunnerState extends State<ExerciseRunner> {
  late final List<Exercise> _queue = [...widget.exercises];
  late final int _total = widget.exercises.length;
  final _failed = <Exercise>{};
  int _done = 0;

  // Ответ на текущее упражнение: null — ещё не отвечали.
  bool? _correct;
  String? _picked;
  // Индексы плиток в порядке, в котором их выбрали.
  final List<int> _built = [];

  void _check(bool ok) {
    setState(() => _correct = ok);
    if (!ok) _failed.add(_queue.first);
  }

  void _continue() {
    setState(() {
      final e = _queue.removeAt(0);
      if (_correct == true) {
        _done++;
      } else {
        _queue.add(e);
      }
      _correct = null;
      _picked = null;
      _built.clear();
    });
    if (_queue.isEmpty) {
      widget.onFinished(_total - _failed.length, _total);
    } else {
      _autoplay();
    }
  }

  void _autoplay() {
    final e = _queue.isEmpty ? null : _queue.first;
    if (e is ListenChoose) Speech.say(e.word.hanzi);
  }

  @override
  void initState() {
    super.initState();
    _autoplay();
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) return const SizedBox.shrink();
    final e = _queue.first;
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        LinearProgressIndicator(value: _total == 0 ? 1 : _done / _total),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(_prompt(e), style: t.titleMedium),
              const SizedBox(height: 16),
              ..._content(e, t),
            ],
          ),
        ),
        if (_correct != null) _feedback(e, t),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52)),
            onPressed: _correct != null
                ? _continue
                : (e is BuildSentence && _built.length == e.tiles.length)
                    ? () => _check(_listEq(
                        [for (final i in _built) e.tiles[i]], e.answer))
                    : null,
            child: Text(_correct != null ? 'Продолжить' : 'Проверить'),
          ),
        ),
      ],
    );
  }

  String _prompt(Exercise e) => switch (e) {
        ChooseMeaning() => 'Что означает это слово?',
        ChooseHanzi() => 'Выберите иероглиф',
        ListenChoose() => 'Прослушайте и выберите слово',
        ChooseTone() => 'Как читается это слово?',
        BuildSentence() => 'Соберите предложение',
      };

  List<Widget> _content(Exercise e, TextTheme t) {
    switch (e) {
      case ChooseMeaning(:final word, :final options, :final answer):
        return [
          Center(child: Text(word.hanzi, style: hanziStyle(80))),
          const SizedBox(height: 16),
          ..._options(options, answer, (o) => Text(o, style: t.titleMedium)),
        ];
      case ChooseHanzi(:final word, :final options):
        return [
          Center(child: Text(word.meaning, style: t.headlineSmall,
              textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          ..._options(options, e.answer, (o) => Text(o, style: hanziStyle(28))),
        ];
      case ListenChoose(:final word, :final options):
        return [
          Center(
            child: IconButton.filledTonal(
              iconSize: 48,
              padding: const EdgeInsets.all(20),
              onPressed: () => Speech.say(word.hanzi),
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ),
          const SizedBox(height: 16),
          ..._options(options, e.answer, (o) => Text(o, style: hanziStyle(28))),
        ];
      case ChooseTone(:final word, :final options):
        return [
          Center(child: Text(word.hanzi, style: hanziStyle(80))),
          Center(child: Text(word.meaning, style: t.bodyMedium)),
          const SizedBox(height: 16),
          ..._options(options, e.answer, (o) => Text(o, style: t.titleLarge)),
        ];
      case BuildSentence(:final sentence, :final tiles):
        return [
          Text(sentence.ru, style: t.headlineSmall),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _built.length; i++)
                  ActionChip(
                    label: Text(tiles[_built[i]], style: hanziStyle(22)),
                    onPressed: _correct != null
                        ? null
                        : () => setState(() => _built.removeAt(i)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < tiles.length; i++)
                Opacity(
                  opacity: _built.contains(i) ? 0.25 : 1,
                  child: ActionChip(
                    label: Text(tiles[i], style: hanziStyle(22)),
                    onPressed: _built.contains(i) || _correct != null
                        ? null
                        : () => setState(() => _built.add(i)),
                  ),
                ),
            ],
          ),
        ];
    }
  }

  List<Widget> _options(
      List<String> options, String answer, Widget Function(String) label) {
    return [
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: _correct == null
                  ? null
                  : o == answer
                      ? Palette.jade.withValues(alpha: 0.15)
                      : o == _picked
                          ? Palette.cinnabar.withValues(alpha: 0.15)
                          : null,
              side: BorderSide(
                color: _correct != null && o == answer
                    ? Palette.jade
                    : _correct != null && o == _picked
                        ? Palette.cinnabar
                        : Theme.of(context).colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            onPressed: _correct != null
                ? null
                : () {
                    _picked = o;
                    _check(o == answer);
                  },
            child: label(o),
          ),
        ),
    ];
  }

  Widget _feedback(Exercise e, TextTheme t) {
    final ok = _correct!;
    final detail = switch (e) {
      ChooseMeaning(:final word) ||
      ChooseHanzi(:final word) ||
      ListenChoose(:final word) ||
      ChooseTone(:final word) =>
        '${word.hanzi}  ${word.pinyin}  ${word.meaning}',
      BuildSentence(:final sentence) => '${sentence.zh}\n${sentence.py}',
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (ok ? Palette.jade : Palette.cinnabar).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(ok ? 'Верно!' : 'Не совсем. Правильно:',
              style: t.titleSmall?.copyWith(
                  color: ok ? Palette.jade : Palette.cinnabar)),
          const SizedBox(height: 4),
          Text(detail, style: hanziStyle(16)),
        ],
      ),
    );
  }
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
