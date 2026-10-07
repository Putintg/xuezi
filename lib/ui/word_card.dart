import 'package:flutter/material.dart';

import '../data/word.dart';
import '../hanzi/hanzi_data.dart';
import '../hanzi/stroke_view.dart';
import '../state/app_state.dart';
import 'writing_screen.dart';
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WordDetails(w),
              const SizedBox(height: 16),
              CharacterBreakdown(w.hanzi),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Разбор каждого иероглифа слова: порядок черт и из чего он состоит.
class CharacterBreakdown extends StatefulWidget {
  const CharacterBreakdown(this.text, {super.key});
  final String text;

  @override
  State<CharacterBreakdown> createState() => _CharacterBreakdownState();
}

class _CharacterBreakdownState extends State<CharacterBreakdown> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    HanziData.ensureLoaded().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final chars = <String>[];
    for (final c in widget.text.split('')) {
      if (HanziData.strokes(c) != null && !chars.contains(c)) chars.add(c);
    }
    if (chars.isEmpty) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('Как писать и из чего состоит', style: t.titleMedium),
        const SizedBox(height: 8),
        for (final c in chars) _charRow(context, c, t),
      ],
    );
  }

  Widget _charRow(BuildContext context, String c, TextTheme t) {
    final parts = HanziData.parts(c);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    String label(String p) {
      final m = HanziData.meaning(p);
      return m == null ? p : '$p  $m';
    }

    final comps = parts?.parts ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StrokeOrderView(c, size: 120),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Черт: ${HanziData.strokes(c)!.count}',
                    style: t.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: 6),
                if (comps.isNotEmpty) ...[
                  Text('Состоит из:', style: t.bodySmall?.copyWith(color: muted)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in comps)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(label(p)),
                        ),
                    ],
                  ),
                ],
                if (parts?.semantic != null && parts!.semantic!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Смысл подсказывает ${parts.semantic}'
                    '${parts.phonetic != null && parts.phonetic!.isNotEmpty ? ', звучание: ${parts.phonetic}' : ''}',
                    style: t.bodySmall,
                  ),
                ] else if (parts != null && parts.radical.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Ключ: ${label(parts.radical)}', style: t.bodySmall),
                ],
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Прописать'),
                  onPressed: AppState.current == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => WritingScreen(
                              state: AppState.current!, chars: [c]))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
