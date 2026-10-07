/// Предложение с пиньинем, переводом и разбивкой на слова.
class Sentence {
  final String zh;
  final String py;
  final String ru;
  final List<String> tokens;
  final String? who;

  const Sentence(
      {required this.zh,
      required this.py,
      required this.ru,
      required this.tokens,
      this.who});

  factory Sentence.fromJson(Map<String, dynamic> j) => Sentence(
        zh: j['zh'] as String,
        py: j['py'] as String,
        ru: j['ru'] as String,
        tokens: [for (final t in j['tokens'] as List) t as String],
        who: j['who'] as String?,
      );

  /// Слова без знаков препинания — из них собирают предложение.
  List<String> get wordTokens =>
      tokens.where((t) => !_punct.hasMatch(t)).toList();
}

final _punct = RegExp(r'^[，。？！、：；“”‘’（）,.?!:;\s]+$');

class GrammarPoint {
  final String title;
  final String pattern;
  final String explanation;
  final List<Sentence> examples;

  const GrammarPoint(
      {required this.title,
      required this.pattern,
      required this.explanation,
      required this.examples});

  factory GrammarPoint.fromJson(Map<String, dynamic> j) => GrammarPoint(
        title: j['title'] as String,
        pattern: j['pattern'] as String,
        explanation: j['explanation'] as String,
        examples: [
          for (final e in j['examples'] as List)
            Sentence.fromJson(e as Map<String, dynamic>)
        ],
      );
}

/// Слово урока, которого нет в словаре HSK.
class ExtraWord {
  final String hanzi;
  final String pinyin;
  final String ru;
  const ExtraWord(this.hanzi, this.pinyin, this.ru);
}

/// Урок: тема, слова, грамматика, диалог.
class Lesson {
  final int id;
  final int level;
  final String title;
  final String titleZh;
  final String goal;
  final List<String> words;
  final List<ExtraWord> extraWords;
  final List<GrammarPoint> grammar;
  final String dialogueTitle;
  final List<Sentence> dialogue;
  final String culture;

  const Lesson({
    required this.id,
    required this.level,
    required this.title,
    required this.titleZh,
    required this.goal,
    required this.words,
    required this.extraWords,
    required this.grammar,
    required this.dialogueTitle,
    required this.dialogue,
    required this.culture,
  });

  factory Lesson.fromJson(Map<String, dynamic> j, {int level = 1}) {
    final d = j['dialogue'] as Map<String, dynamic>;
    return Lesson(
      id: j['id'] as int,
      level: (j['level'] as int?) ?? level,
      title: j['title'] as String,
      titleZh: j['titleZh'] as String,
      goal: j['goal'] as String,
      words: [for (final w in j['words'] as List) w as String],
      extraWords: [
        for (final e in (j['extraWords'] as List?) ?? const [])
          ExtraWord(e['h'] as String, e['p'] as String, e['ru'] as String)
      ],
      grammar: [
        for (final g in j['grammar'] as List)
          GrammarPoint.fromJson(g as Map<String, dynamic>)
      ],
      dialogueTitle: d['title'] as String,
      dialogue: [
        for (final l in d['lines'] as List)
          Sentence.fromJson(l as Map<String, dynamic>)
      ],
      culture: (j['culture'] as String?) ?? '',
    );
  }

  /// Уникальный ключ для сохранения прогресса.
  String get key => 'L$level-$id';
}
