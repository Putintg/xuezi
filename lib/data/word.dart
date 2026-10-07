/// Одно слово из словаря HSK.
class Word {
  final int id;
  final String hanzi;
  final String traditional;
  final String pinyin;
  final String ru;
  final String en;
  final int level;
  final String example;
  final String examplePinyin;
  final String exampleRu;

  const Word({
    required this.id,
    required this.hanzi,
    required this.traditional,
    required this.pinyin,
    required this.ru,
    required this.en,
    required this.level,
    required this.example,
    required this.examplePinyin,
    required this.exampleRu,
  });

  factory Word.fromJson(int id, Map<String, dynamic> j) => Word(
        id: id,
        hanzi: j['h'] as String,
        traditional: (j['t'] as String?) ?? j['h'] as String,
        pinyin: j['p'] as String,
        ru: (j['ru'] as String?) ?? '',
        en: (j['en'] as String?) ?? '',
        level: j['l'] as int,
        example: (j['ex'] as String?) ?? '',
        examplePinyin: (j['exp'] as String?) ?? '',
        exampleRu: (j['exru'] as String?) ?? '',
      );

  /// Перевод для показа: русский, если есть, иначе английский.
  String get meaning => ru.isNotEmpty ? ru : en;
}
