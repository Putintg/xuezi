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

/// Полная карточка слова: иероглиф, пиньинь, перевод, пример.
class WordDetails extends StatelessWidget {
  const WordDetails(this.word, {super.key, this.hanziSize = 96});
  final Word word;
  final double hanziSize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            LevelBadge(word.level),
            const Spacer(),
            IconButton(
              tooltip: 'Произнести',
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: () => Speech.say(word.hanzi),
            ),
          ],
        ),
        Center(child: Text(word.hanzi, style: hanziStyle(hanziSize))),
        if (word.traditional != word.hanzi)
          Center(
            child: Text('трад. ${word.traditional}',
                style: t.bodySmall?.copyWith(color: muted)),
          ),
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
        if (word.example.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => Speech.say(word.example),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.example, style: hanziStyle(22)),
                  const SizedBox(height: 2),
                  Text(word.examplePinyin,
                      style: t.bodyMedium?.copyWith(color: muted)),
                  const SizedBox(height: 2),
                  Text(word.exampleRu, style: t.bodyMedium),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
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
