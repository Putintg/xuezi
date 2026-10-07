import 'dart:convert';
import 'dart:io';

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
}
