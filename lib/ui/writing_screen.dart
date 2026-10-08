import 'dart:math';

import 'package:flutter/material.dart';

import '../hanzi/hanzi_data.dart';
import '../hanzi/stroke_view.dart';
import '../hanzi/writing_pad.dart';
import '../state/app_state.dart';
import 'theme.dart';

/// Прописи: каждый иероглиф пишется несколько раз, последний раз без
/// подсказки-контура.
class WritingScreen extends StatefulWidget {
  const WritingScreen(
      {super.key,
      required this.state,
      required this.chars,
      this.repeats = 3,
      this.homework = false});
  final AppState state;
  final List<String> chars;
  final int repeats;

  /// Засчитывать в домашнее задание.
  final bool homework;

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  int _char = 0;
  int _round = 0;
  int? _lastMistakes;
  int _stroke = 0;
  int _strokes = 0;
  GlobalKey<WritingPadState> _pad = GlobalKey();

  void _restart() => setState(() {
        _pad = GlobalKey();
        _stroke = 0;
      });

  @override
  void initState() {
    super.initState();
    if (widget.homework) {
      // Продолжаем с первого недописанного иероглифа.
      final i = widget.chars.indexWhere(
          (c) => (widget.state.homeworkDone[c] ?? 0) < widget.repeats);
      if (i > 0) _char = i;
      if (i >= 0) _round = widget.state.homeworkDone[widget.chars[i]] ?? 0;
    }
  }

  bool get _finished => _char >= widget.chars.length;

  Future<void> _done(int mistakes) async {
    final c = widget.chars[_char];
    if (widget.homework) await widget.state.markWritten(c);
    setState(() => _lastMistakes = mistakes);
  }

  void _next() => setState(() {
        _lastMistakes = null;
        _pad = GlobalKey();
        _stroke = 0;
        _round++;
        if (_round >= widget.repeats) {
          _round = 0;
          _char++;
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.homework ? 'Домашнее задание' : 'Прописи')),
      body: SafeArea(
        child: _finished
            ? _finishedView(t)
            : LayoutBuilder(builder: (context, box) {
                final c = widget.chars[_char];
                final w = widget.state.wordByHanzi(c);
                // Без прокрутки: всё касание принадлежит клетке.
                final size = min(box.maxWidth - 32, box.maxHeight - 250)
                    .clamp(200.0, 520.0);
                final lastRound = _round == widget.repeats - 1;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: (_char * widget.repeats + _round) /
                            (widget.chars.length * widget.repeats),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          'Иероглиф ${_char + 1} из ${widget.chars.length} · '
                          'раз ${_round + 1} из ${widget.repeats}',
                          style: t.bodySmall),
                      if (w != null)
                        Text('${w.pinyin} — ${w.meaning}',
                            textAlign: TextAlign.center,
                            style: t.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                          _lastMistakes != null
                              ? (_lastMistakes == 0
                                  ? 'Отлично, без ошибок!'
                                  : 'Готово. Ошибок: $_lastMistakes')
                              : lastRound
                                  ? 'Теперь по памяти, без контура'
                                  : 'Обведите черту ${_stroke + 1}'
                                      '${_strokes > 0 ? ' из $_strokes' : ''}',
                          style: t.bodyMedium?.copyWith(
                              color: _lastMistakes == 0
                                  ? Palette.jade
                                  : Palette.cinnabar)),
                      const Spacer(),
                      WritingPad(
                        c,
                        key: _pad,
                        size: size,
                        showOutline: !lastRound,
                        onDone: _done,
                        onProgress: (d, n) => setState(() {
                          _stroke = d;
                          _strokes = n;
                        }),
                      ),
                      const Spacer(),
                      if (_lastMistakes != null)
                        FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52)),
                          onPressed: _next,
                          child: Text(_round + 1 >= widget.repeats &&
                                  _char + 1 >= widget.chars.length
                              ? 'Завершить'
                              : 'Дальше'),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48)),
                                icon: const Icon(Icons.lightbulb_outline),
                                label: const Text('Подсказка'),
                                onPressed: () =>
                                    _pad.currentState?.showHint(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(48)),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Как писать'),
                                onPressed: () => _showOrder(c),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Начать заново',
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: _restart,
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
      ),
    );
  }

  void _showOrder(String c) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeOrderView(c, size: 240),
              const SizedBox(height: 8),
              Text(
                  'Черт: ${HanziData.strokes(c)?.count ?? '?'} · коснитесь, чтобы повторить',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _finishedView(TextTheme t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('写得好!', style: hanziStyle(56, color: Palette.cinnabar)),
              const SizedBox(height: 12),
              Text(
                  'Прописано иероглифов: ${widget.chars.length} × ${widget.repeats}',
                  style: t.titleMedium),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Готово')),
            ],
          ),
        ),
      );
}
