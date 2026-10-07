import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:xuezi/data/word.dart';
import 'package:xuezi/lessons/exercises.dart';
import 'package:xuezi/lessons/lesson.dart';

void main() {
  final words = [
    for (final (i, w) in (jsonDecode(File('assets/words.json').readAsStringSync())
            as List)
        .indexed)
      Word.fromJson(i, w as Map<String, dynamic>)
  ];
  final byHanzi = {for (final w in words) w.hanzi: w};
  final lessons = [
    for (final l in jsonDecode(
            File('assets/lessons/hsk1.json').readAsStringSync()) as List)
      Lesson.fromJson(l as Map<String, dynamic>)
  ];

  test('варианты тонов отличаются от ответа и сохраняют слоги', () {
    final v = toneVariants('lǎoshī', Random(1));
    expect(v, isNotEmpty);
    for (final x in v) {
      expect(x, isNot('lǎoshī'));
      expect(x.length, 'lǎoshī'.length);
    }
    expect(toneVariants('de', Random(1)), isEmpty);
  });

  test('уроки HSK 1 покрывают словарь и корректно размечены', () {
    expect(lessons.length, 10);
    final covered = [for (final l in lessons) ...l.words];
    expect(covered.toSet().length, covered.length, reason: 'слова не повторяются');
    expect(covered.length, greaterThanOrEqualTo(140));
    for (final h in covered) {
      expect(byHanzi[h], isNotNull, reason: h);
    }
    for (final l in lessons) {
      for (final s in [
        for (final g in l.grammar) ...g.examples,
        ...l.dialogue
      ]) {
        expect(s.tokens.join(), s.zh, reason: s.zh);
      }
    }
  });

  test('упражнения урока: правильный ответ всегда среди вариантов', () {
    for (final l in lessons) {
      final lw = [for (final h in l.words) byHanzi[h]!];
      final ex = buildExercises(l, lw, words.where((w) => w.level <= 2).toList(),
          random: Random(l.id));
      expect(ex.length, greaterThanOrEqualTo(10));
      for (final e in ex) {
        switch (e) {
          case ChooseMeaning(:final options, :final answer):
            expect(options, contains(answer));
            expect(options.toSet().length, 4);
          case ChooseHanzi(:final options):
            expect(options, contains(e.answer));
          case ListenChoose(:final options):
            expect(options, contains(e.answer));
          case ChooseTone(:final options):
            expect(options, contains(e.answer));
          case BuildSentence(:final tiles):
            expect([...tiles]..sort(), [...e.answer]..sort());
        }
      }
    }
  });
}
