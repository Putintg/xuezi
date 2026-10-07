import 'package:flutter/material.dart';

import '../data/word.dart';
import '../services/speech.dart';
import '../srs/srs.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'word_card.dart';

/// Занятие: карточки из очереди повторений и новых слов.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.state, this.practice});
  final AppState state;

  /// Свободное повторение этих слов: расписание повторений не меняется.
  final List<Word>? practice;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final List<Word> _queue;
  late final int _total;
  int _done = 0;
  Reveal _reveal = Reveal.hanzi;

  @override
  void initState() {
    super.initState();
    _queue = widget.practice != null
        ? [...widget.practice!]
        : widget.state.sessionQueue(DateTime.now());
    _total = _queue.length;
  }

  String _preview(Word w, Grade g) {
    final prev = widget.state.cards[w.id];
    final copy = prev == null ? null : CardState.fromJson(prev.toJson());
    final next = review(copy, g, DateTime.now());
    if (g == Grade.again) return '10 мин';
    final d = next.intervalDays;
    if (d < 30) return '$d дн';
    if (d < 365) return '${(d / 30).round()} мес';
    return '${(d / 365).toStringAsFixed(1)} г';
  }

  /// Касание открывает карточку по шагам: пример, затем пиньинь и перевод.
  void _advance() {
    if (_reveal == Reveal.full || _queue.isEmpty) return;
    setState(() => _reveal = Reveal.values[_reveal.index + 1]);
    if (_reveal == Reveal.full) Speech.say(_queue.first.hanzi);
  }

  Future<void> _answer(Grade g) async {
    final w = _queue.removeAt(0);
    if (widget.practice == null) await widget.state.answer(w, g);
    setState(() {
      if (g == Grade.again) {
        _queue.add(w); // вернётся в конце занятия
      } else {
        _done++;
      }
      _reveal = Reveal.hanzi;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.practice != null ? 'Повторение' : 'Занятие'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: _total == 0 ? 1 : _done / _total),
        ),
      ),
      body: SafeArea(
        child: _queue.isEmpty ? _finished(context) : _card(context, t),
      ),
    );
  }

  Widget _finished(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('好!', style: hanziStyle(72, color: Palette.cinnabar)),
              const SizedBox(height: 12),
              Text('Занятие окончено: $_done карточек',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Готово')),
            ],
          ),
        ),
      );

  Widget _card(BuildContext context, TextTheme t) {
    final w = _queue.first;
    final isNew = !widget.state.cards.containsKey(w.id);
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNew)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Text('Новое слово',
                          style: t.labelLarge
                              ?.copyWith(color: Palette.cinnabar)),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: WordDetails(w, hanziSize: 112, reveal: _reveal),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _reveal == Reveal.full
              ? Row(
                  children: [
                    for (final (g, label, color) in [
                      (Grade.again, 'Снова', Palette.cinnabar),
                      (Grade.hard, 'Трудно', Palette.level(3)),
                      (Grade.good, 'Хорошо', Palette.jade),
                      (Grade.easy, 'Легко', Palette.level(2)),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: color,
                            ),
                            onPressed: () => _answer(g),
                            child: Column(children: [
                              Text(label),
                              if (widget.practice == null)
                                Text(_preview(w, g), style: t.labelSmall),
                            ]),
                          ),
                        ),
                      ),
                  ],
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  onPressed: _advance,
                  child: Text(_reveal == Reveal.hanzi
                      ? 'Показать пример'
                      : 'Показать пиньинь и перевод'),
                ),
        ),
      ],
    );
  }
}
