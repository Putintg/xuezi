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
  int _padKey = 0;

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
        _padKey++;
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
                final size = (box.maxWidth - 48).clamp(200.0, 360.0);
                final lastRound = _round == widget.repeats - 1;
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    LinearProgressIndicator(
                      value: (_char * widget.repeats + _round) /
                          (widget.chars.length * widget.repeats),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Иероглиф ${_char + 1} из ${widget.chars.length} · '
                                  'раз ${_round + 1} из ${widget.repeats}',
                                  style: t.bodySmall),
                              if (w != null)
                                Text('${w.pinyin} — ${w.meaning}',
                                    style: t.titleMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              Text(
                                  lastRound
                                      ? 'Теперь по памяти, без подсказки'
                                      : 'Пишите черту за чертой по контуру',
                                  style: t.bodyMedium?.copyWith(
                                      color: Palette.cinnabar)),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Порядок черт',
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: () => _showOrder(c),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: WritingPad(
                        c,
                        key: ValueKey('$c-$_padKey'),
                        size: size,
                        showOutline: !lastRound,
                        onDone: _done,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_lastMistakes != null) ...[
                      Text(
                        _lastMistakes == 0
                            ? 'Отлично, без ошибок!'
                            : 'Готово. Ошибок в чертах: $_lastMistakes',
                        textAlign: TextAlign.center,
                        style: t.titleMedium?.copyWith(
                            color: _lastMistakes == 0
                                ? Palette.jade
                                : Palette.level(3)),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: _next,
                        child: const Text('Дальше'),
                      ),
                    ] else
                      TextButton(
                        onPressed: () => setState(() => _padKey++),
                        child: const Text('Начать заново'),
                      ),
                  ],
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
