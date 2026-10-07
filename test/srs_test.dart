import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xuezi/srs/srs.dart';

void main() {
  final now = DateTime(2026, 10, 7, 12);

  test('новая карточка с ответом «хорошо» придёт завтра', () {
    final s = review(null, Grade.good, now);
    expect(s.reps, 1);
    expect(s.due, DateTime(2026, 10, 8));
  });

  test('интервалы растут при правильных ответах', () {
    var s = review(null, Grade.good, now);
    final intervals = <int>[];
    for (var i = 0; i < 5; i++) {
      s = review(s, Grade.good, s.due);
      intervals.add(s.intervalDays);
    }
    for (var i = 1; i < intervals.length; i++) {
      expect(intervals[i], greaterThan(intervals[i - 1]));
    }
  });

  test('«снова» сбрасывает прогресс и показывает через 10 минут', () {
    var s = review(null, Grade.good, now);
    s = review(s, Grade.good, s.due);
    s = review(s, Grade.again, now);
    expect(s.reps, 0);
    expect(s.lapses, 1);
    expect(s.due, now.add(const Duration(minutes: 10)));
  });

  test('состояние переживает сериализацию', () {
    final s = review(null, Grade.easy, now);
    final back = CardState.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
    expect(back.intervalDays, s.intervalDays);
    expect(back.due, s.due);
    expect(back.ease, s.ease);
  });

  test('словарь: 6 уровней HSK 3.0, у каждого слова есть перевод и пример', () {
    final words =
        jsonDecode(File('assets/words.json').readAsStringSync()) as List;
    expect(words.length, greaterThan(5000));
    expect(words.map((w) => w['l']).toSet(), {1, 2, 3, 4, 5, 6});
    for (final w in words) {
      expect((w['ru'] as String).isNotEmpty, true, reason: '${w['h']}');
      expect((w['ex'] as String).contains(w['h'] as String), true,
          reason: '${w['h']}');
    }
  });
}
