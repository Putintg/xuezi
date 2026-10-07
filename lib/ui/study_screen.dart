import 'package:flutter/material.dart';

import '../data/word.dart';
import '../services/speech.dart';
import '../srs/srs.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'word_card.dart';

/// Занятие: карточки из очереди повторений и новых слов.
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, required this.state});
  final AppState state;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final List<Word> _queue;
  late final int _total;
  int _done = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _queue = widget.state.sessionQueue(DateTime.now());
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

  Future<void> _answer(Grade g) async {
    final w = _queue.removeAt(0);
    await widget.state.answer(w, g);
    setState(() {
      if (g == Grade.again) {
        _queue.add(w); // вернётся в конце занятия
      } else {
        _done++;
      }
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Занятие'),
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
            onTap: () {
              if (!_revealed) {
                setState(() => _revealed = true);
                Speech.say(w.hanzi);
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: _revealed
                      ? WordDetails(w, hanziSize: 104)
                      : Column(
                          children: [
                            Row(children: [
                              LevelBadge(w.level),
                              const Spacer(),
                              if (isNew)
                                Text('новое',
                                    style: t.labelMedium
                                        ?.copyWith(color: Palette.cinnabar)),
                            ]),
                            const SizedBox(height: 40),
                            Text(w.hanzi, style: hanziStyle(120)),
                            const SizedBox(height: 40),
                            Text('Вспомните чтение и значение,\nзатем коснитесь карточки',
                                textAlign: TextAlign.center,
                                style: t.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _revealed
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
                  onPressed: () {
                    setState(() => _revealed = true);
                    Speech.say(w.hanzi);
                  },
                  child: const Text('Показать ответ'),
                ),
        ),
      ],
    );
  }
}
