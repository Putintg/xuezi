import 'package:flutter/material.dart';

import '../data/word.dart';
import '../services/speech.dart';
import 'theme.dart';

class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});
  final int level;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Palette.level(level).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('HSK $level',
            style: TextStyle(
                color: Palette.level(level),
                fontWeight: FontWeight.w600,
                fontSize: 12)),
      );
}

/// Сколько показано на карточке: иероглифы, затем пример, затем всё.
enum Reveal { hanzi, example, full }

/// Карточка слова. [reveal] скрывает подсказки, чтобы сначала вспомнить
/// чтение и значение самому.
class WordDetails extends StatelessWidget {
  const WordDetails(this.word,
      {super.key, this.hanziSize = 96, this.reveal = Reveal.full});
  final Word word;
  final double hanziSize;
  final Reveal reveal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final full = reveal == Reveal.full;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            LevelBadge(word.level),
            const Spacer(),
            if (full)
              IconButton(
                tooltip: 'Произнести',
                icon: const Icon(Icons.volume_up_rounded),
                onPressed: () => Speech.say(word.hanzi),
              )
            else
              const SizedBox(height: 48),
          ],
        ),
        Center(child: Text(word.hanzi, style: hanziStyle(hanziSize))),
        if (full && word.traditional != word.hanzi)
          Center(
            child: Text('трад. ${word.traditional}',
                style: t.bodySmall?.copyWith(color: muted)),
          ),
        if (full) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(word.pinyin,
                style: t.headlineSmall?.copyWith(color: Palette.cinnabar)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(word.meaning,
                textAlign: TextAlign.center, style: t.titleMedium),
          ),
        ],
        if (reveal != Reveal.hanzi && word.example.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: full ? () => Speech.say(word.example) : null,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.example, style: hanziStyle(22)),
                  if (full) ...[
                    const SizedBox(height: 2),
                    Text(word.examplePinyin,
                        style: t.bodyMedium?.copyWith(color: muted)),
                    const SizedBox(height: 2),
                    Text(word.exampleRu, style: t.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (!full) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(
              reveal == Reveal.hanzi
                  ? 'Коснитесь, чтобы увидеть пример'
                  : 'Коснитесь ещё раз: пиньинь и перевод',
              style: t.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ],
    );
  }
}

/// Карточка, которая открывается по касаниям: иероглиф, пример, перевод.
class TapRevealCard extends StatefulWidget {
  const TapRevealCard(this.word, {super.key, this.hanziSize = 112});
  final Word word;
  final double hanziSize;

  @override
  State<TapRevealCard> createState() => _TapRevealCardState();
}

class _TapRevealCardState extends State<TapRevealCard> {
  Reveal _reveal = Reveal.hanzi;

  @override
  void didUpdateWidget(TapRevealCard old) {
    super.didUpdateWidget(old);
    if (old.word.id != widget.word.id) _reveal = Reveal.hanzi;
  }

  void _next() {
    if (_reveal == Reveal.full) return;
    setState(() => _reveal = Reveal.values[_reveal.index + 1]);
    if (_reveal == Reveal.full) Speech.say(widget.word.hanzi);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: WordDetails(widget.word,
            hanziSize: widget.hanziSize, reveal: _reveal),
      );
}

void showWordSheet(BuildContext context, Word w) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SingleChildScrollView(child: WordDetails(w)),
      ),
    ),
  );
}
