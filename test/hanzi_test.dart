import 'dart:convert';
import 'dart:io';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuezi/hanzi/hanzi_data.dart';
import 'package:xuezi/hanzi/writing_pad.dart';

void main() {
  final strokes = jsonDecode(File('assets/hanzi/strokes.json').readAsStringSync())
      as Map<String, dynamic>;
  final parts = jsonDecode(File('assets/hanzi/parts.json').readAsStringSync())
      as Map<String, dynamic>;
  HanziData.debugSet(strokes, parts['chars'] as Map<String, dynamic>,
      parts['ru'] as Map<String, dynamic>);

  test('у каждого иероглифа словаря есть черты', () {
    final words = jsonDecode(File('assets/words.json').readAsStringSync()) as List;
    final chars = {
      for (final w in words)
        for (final c in (w['h'] as String).split(''))
          if (c.codeUnitAt(0) >= 0x4e00 && c.codeUnitAt(0) <= 0x9fff) c
    };
    final missing = chars.where((c) => HanziData.strokes(c) == null).toList();
    expect(missing, isEmpty);
  });

  test('一 — одна горизонтальная черта; 好 = 女 + 子', () {
    final yi = HanziData.strokes('一')!;
    expect(yi.count, 1);
    final b = yi.outlines.first.getBounds();
    expect(b.width, greaterThan(b.height * 3));
    expect(HanziData.parts('好')!.parts, ['女', '子']);
    expect(HanziData.strokes('好')!.count, 6);
  });

  test('проверка черты: эталон проходит, обратное направление — нет', () {
    final m = HanziData.strokes('一')!.medians.first;
    expect(strokeMatches(m, m), isTrue);
    expect(strokeMatches(m.reversed.toList(), m), isFalse);
    expect(strokeMatches([const Offset(0, 0), const Offset(10, 900)], m), isFalse);
  });

  test('неровная черта пальцем засчитывается, чужая — нет', () {
    final rnd = Random(7);
    var ok = 0, total = 0, wrong = 0;
    for (final c in ['好', '我', '学', '字', '国', '爱', '谢', '鸟']) {
      final s = HanziData.strokes(c)!;
      for (var i = 0; i < s.count; i++) {
        final m = resample(s.medians[i], 12);
        // Сдвиг всей черты и дрожание руки.
        final shift = Offset(rnd.nextDouble() * 120 - 60, rnd.nextDouble() * 120 - 60);
        final drawn = [
          for (final p in m)
            p + shift + Offset(rnd.nextDouble() * 50 - 25, rnd.nextDouble() * 50 - 25)
        ];
        total++;
        if (strokeMatches(drawn, s.medians[i])) ok++;
        if (strokeMatches(drawn.reversed.toList(), s.medians[i]) &&
            (s.medians[i].first - s.medians[i].last).distance > 300) {
          wrong++;
        }
      }
    }
    expect(ok, total);
    expect(wrong, 0);
  });

  testWidgets('черта рисуется пальцем внутри прокрутки', (tester) async {
    var done = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          WritingPad('一', size: 300, onDone: (m) => done = m),
          const SizedBox(height: 1000),
        ]),
      ),
    ));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final m = HanziData.strokes('一')!.medians.first;
    final origin = tester.getTopLeft(find.byType(WritingPad));
    final g = await tester.startGesture(origin + m.first * (300 / 1024));
    for (final p in resample(m, 10).skip(1)) {
      await g.moveTo(origin + p * (300 / 1024));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
    expect(done, 0);
  });
}
