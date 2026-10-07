import 'dart:math';

import '../data/word.dart';
import 'lesson.dart';

/// Упражнение урока. Варианты ответа уже перемешаны.
sealed class Exercise {
  const Exercise();
}

/// Иероглиф → выбрать значение.
class ChooseMeaning extends Exercise {
  final Word word;
  final List<String> options;
  final String answer;
  const ChooseMeaning(this.word, this.options, this.answer);
}

/// Значение → выбрать иероглиф.
class ChooseHanzi extends Exercise {
  final Word word;
  final List<String> options;
  const ChooseHanzi(this.word, this.options);
  String get answer => word.hanzi;
}

/// Прослушать слово → выбрать иероглиф.
class ListenChoose extends Exercise {
  final Word word;
  final List<String> options;
  const ListenChoose(this.word, this.options);
  String get answer => word.hanzi;
}

/// Иероглиф → выбрать пиньинь с правильными тонами.
class ChooseTone extends Exercise {
  final Word word;
  final List<String> options;
  const ChooseTone(this.word, this.options);
  String get answer => word.pinyin;
}

/// Перевод → собрать китайское предложение из плиток.
class BuildSentence extends Exercise {
  final Sentence sentence;
  final List<String> tiles;
  const BuildSentence(this.sentence, this.tiles);
  List<String> get answer => sentence.wordTokens;
}

const _tones = {
  'a': ['a', 'ā', 'á', 'ǎ', 'à'],
  'e': ['e', 'ē', 'é', 'ě', 'è'],
  'i': ['i', 'ī', 'í', 'ǐ', 'ì'],
  'o': ['o', 'ō', 'ó', 'ǒ', 'ò'],
  'u': ['u', 'ū', 'ú', 'ǔ', 'ù'],
  'ü': ['ü', 'ǖ', 'ǘ', 'ǚ', 'ǜ'],
};

/// Варианты того же пиньиня с другими тонами — для упражнения на тоны.
List<String> toneVariants(String pinyin, Random rnd, {int count = 3}) {
  final marked = <int, String>{}; // позиция → базовая гласная
  for (var i = 0; i < pinyin.length; i++) {
    for (final e in _tones.entries) {
      final idx = e.value.indexOf(pinyin[i]);
      if (idx > 0) marked[i] = e.key;
    }
  }
  if (marked.isEmpty) return const [];
  final out = <String>{};
  for (var attempt = 0; attempt < 40 && out.length < count; attempt++) {
    final chars = pinyin.split('');
    // Меняем тон у одного или двух слогов.
    final positions = marked.keys.toList()..shuffle(rnd);
    final n = positions.length > 1 && rnd.nextBool() ? 2 : 1;
    for (final p in positions.take(n)) {
      final forms = _tones[marked[p]]!;
      chars[p] = forms[1 + rnd.nextInt(4)];
    }
    final v = chars.join();
    if (v != pinyin) out.add(v);
  }
  return out.toList();
}

/// Собирает упражнения урока: слова, тоны и предложения.
List<Exercise> buildExercises(Lesson lesson, List<Word> lessonWords,
    List<Word> pool, {Random? random}) {
  final rnd = random ?? Random();
  final out = <Exercise>[];

  List<Word> distractors(Word w, int n) {
    final others = [...pool]..shuffle(rnd);
    final seenHanzi = {w.hanzi};
    final seenMeaning = {w.meaning};
    final out = <Word>[];
    for (final o in others) {
      if (out.length == n) break;
      if (seenHanzi.add(o.hanzi) && seenMeaning.add(o.meaning)) out.add(o);
    }
    return out;
  }

  final words = [...lessonWords]..shuffle(rnd);
  for (var i = 0; i < words.length && i < 9; i++) {
    final w = words[i];
    final wrong = distractors(w, 3);
    switch (i % 3) {
      case 0:
        out.add(ChooseMeaning(
            w, ([w.meaning, ...wrong.map((o) => o.meaning)]..shuffle(rnd)),
            w.meaning));
      case 1:
        out.add(ChooseHanzi(
            w, [w.hanzi, ...wrong.map((o) => o.hanzi)]..shuffle(rnd)));
      default:
        out.add(ListenChoose(
            w, [w.hanzi, ...wrong.map((o) => o.hanzi)]..shuffle(rnd)));
    }
  }

  var toneCount = 0;
  for (final w in words.reversed) {
    if (toneCount >= 3) break;
    final variants = toneVariants(w.pinyin, rnd);
    if (variants.length < 2) continue;
    out.add(ChooseTone(w, [w.pinyin, ...variants]..shuffle(rnd)));
    toneCount++;
  }

  final sentences = [
    for (final g in lesson.grammar) ...g.examples,
    ...lesson.dialogue,
  ].where((s) {
    final n = s.wordTokens.length;
    return n >= 3 && n <= 8;
  }).toList()
    ..shuffle(rnd);
  for (final s in sentences.take(3)) {
    var tiles = [...s.wordTokens];
    // Плитки не должны сразу стоять в правильном порядке.
    for (var i = 0; i < 5 && _same(tiles, s.wordTokens); i++) {
      tiles.shuffle(rnd);
    }
    out.add(BuildSentence(s, tiles));
  }

  // Слова сначала, предложения в конце — от простого к сложному.
  return out;
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
