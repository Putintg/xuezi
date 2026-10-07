import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/word.dart';
import '../srs/srs.dart';

String dayKey(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// Всё состояние приложения: словарь, прогресс и настройки.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  final SharedPreferences _prefs;
  List<Word> words = [];
  final Map<int, CardState> cards = {};

  bool onboarded = false;
  Set<int> levels = {1};
  int dailyNew = 5;
  Set<String> studyDays = {};

  // Экран блокировки
  bool lockEnabled = true;
  int lockEveryMinutes = 120;
  int lockStartHour = 9;
  int lockEndHour = 21;

  int _newToday = 0;
  String _newTodayKey = '';
  int reviewedToday = 0;

  /// Вызывается после изменений, которые должны попасть на экран блокировки.
  VoidCallback? onLockscreenDataChanged;

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState(prefs);
    final raw = await rootBundle.loadString('assets/words.json');
    final list = jsonDecode(raw) as List;
    s.words = [
      for (var i = 0; i < list.length; i++)
        Word.fromJson(i, list[i] as Map<String, dynamic>)
    ];
    s._restore();
    return s;
  }

  void _restore() {
    onboarded = _prefs.getBool('onboarded') ?? false;
    levels = (_prefs.getStringList('levels') ?? ['1']).map(int.parse).toSet();
    dailyNew = _prefs.getInt('dailyNew') ?? 5;
    studyDays = (_prefs.getStringList('studyDays') ?? []).toSet();
    lockEnabled = _prefs.getBool('lockEnabled') ?? true;
    lockEveryMinutes = _prefs.getInt('lockEvery') ?? 120;
    lockStartHour = _prefs.getInt('lockStart') ?? 9;
    lockEndHour = _prefs.getInt('lockEnd') ?? 21;
    _newTodayKey = _prefs.getString('newTodayKey') ?? '';
    _newToday = _prefs.getInt('newToday') ?? 0;
    reviewedToday = _prefs.getInt('reviewedToday') ?? 0;
    final c = _prefs.getString('cards');
    if (c != null) {
      (jsonDecode(c) as Map<String, dynamic>).forEach((k, v) {
        cards[int.parse(k)] = CardState.fromJson(v as Map<String, dynamic>);
      });
    }
    _rollDay(DateTime.now());
  }

  void _rollDay(DateTime now) {
    if (_newTodayKey != dayKey(now)) {
      _newTodayKey = dayKey(now);
      _newToday = 0;
      reviewedToday = 0;
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
        'cards',
        jsonEncode(
            cards.map((k, v) => MapEntry(k.toString(), v.toJson()))));
    await _prefs.setStringList('studyDays', studyDays.toList());
    await _prefs.setString('newTodayKey', _newTodayKey);
    await _prefs.setInt('newToday', _newToday);
    await _prefs.setInt('reviewedToday', reviewedToday);
  }

  // ---------- Настройки ----------

  Future<void> completeOnboarding(Set<int> lv, int perDay) async {
    onboarded = true;
    levels = lv;
    dailyNew = perDay;
    await _prefs.setBool('onboarded', true);
    await _saveSettings();
  }

  Future<void> updateSettings({
    Set<int>? levels,
    int? dailyNew,
    bool? lockEnabled,
    int? lockEveryMinutes,
    int? lockStartHour,
    int? lockEndHour,
  }) async {
    if (levels != null && levels.isNotEmpty) this.levels = levels;
    if (dailyNew != null) this.dailyNew = dailyNew;
    if (lockEnabled != null) this.lockEnabled = lockEnabled;
    if (lockEveryMinutes != null) this.lockEveryMinutes = lockEveryMinutes;
    if (lockStartHour != null) this.lockStartHour = lockStartHour;
    if (lockEndHour != null) this.lockEndHour = lockEndHour;
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    await _prefs.setStringList(
        'levels', levels.map((e) => e.toString()).toList());
    await _prefs.setInt('dailyNew', dailyNew);
    await _prefs.setBool('lockEnabled', lockEnabled);
    await _prefs.setInt('lockEvery', lockEveryMinutes);
    await _prefs.setInt('lockStart', lockStartHour);
    await _prefs.setInt('lockEnd', lockEndHour);
    notifyListeners();
    onLockscreenDataChanged?.call();
  }

  // ---------- Учебная очередь ----------

  /// Слова выбранных уровней в порядке изучения.
  List<Word> get studyPool =>
      words.where((w) => levels.contains(w.level)).toList();

  List<Word> get newWords =>
      studyPool.where((w) => !cards.containsKey(w.id)).toList();

  List<Word> dueWords(DateTime now) {
    final due = words
        .where((w) => cards[w.id] != null && !cards[w.id]!.due.isAfter(now))
        .toList();
    due.sort((a, b) => cards[a.id]!.due.compareTo(cards[b.id]!.due));
    return due;
  }

  int get newLeftToday => (dailyNew - _newToday).clamp(0, dailyNew);

  /// Очередь на сейчас: сначала повторения, потом новые слова на сегодня.
  List<Word> sessionQueue(DateTime now) {
    _rollDay(now);
    return [...dueWords(now), ...newWords.take(newLeftToday)];
  }

  /// Иероглиф дня: детерминирован датой, берётся из ближайших новых слов.
  /// Выбор запоминается на весь день, чтобы слово не менялось после занятий.
  Word wordOfTheDay(DateTime now) {
    final key = dayKey(now);
    final savedId = _prefs.getInt('wotdId');
    if (_prefs.getString('wotdKey') == key &&
        savedId != null &&
        savedId < words.length) {
      return words[savedId];
    }
    final pool = newWords.isNotEmpty ? newWords.take(30).toList() : studyPool;
    final d = startOfDay(now);
    final seed = d.year * 400 + d.month * 31 + d.day;
    final w = pool[seed % pool.length];
    _prefs.setString('wotdKey', key);
    _prefs.setInt('wotdId', w.id);
    return w;
  }

  Future<void> answer(Word w, Grade g) async {
    final now = DateTime.now();
    _rollDay(now);
    final wasNew = !cards.containsKey(w.id);
    cards[w.id] = review(cards[w.id], g, now);
    if (wasNew) _newToday++;
    reviewedToday++;
    studyDays.add(dayKey(now));
    await _save();
    notifyListeners();
    onLockscreenDataChanged?.call();
  }

  // ---------- Статистика ----------

  int get streak {
    var n = 0;
    var d = DateTime.now();
    // Сегодняшний день ещё может быть не начат — серия не обнуляется.
    if (!studyDays.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    while (studyDays.contains(dayKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int learnedInLevel(int level) => words
      .where((w) => w.level == level && (cards[w.id]?.isLearned ?? false))
      .length;

  int totalInLevel(int level) => words.where((w) => w.level == level).length;

  int get learnedTotal => cards.values.where((c) => c.isLearned).length;

  /// Слова для экрана блокировки и виджета: сначала те, что пора повторить,
  /// потом недавно изученные, потом ближайшие новые.
  List<Word> lockscreenRotation({int size = 40}) {
    final now = DateTime.now();
    final seen = <int>{};
    final out = <Word>[];
    void add(Iterable<Word> ws) {
      for (final w in ws) {
        if (out.length >= size) return;
        if (seen.add(w.id)) out.add(w);
      }
    }

    add([wordOfTheDay(now)]);
    add(dueWords(now.add(const Duration(days: 1))));
    final young = words
        .where((w) => cards[w.id]?.isLearned == true && !cards[w.id]!.isMature)
        .toList()
      ..sort((a, b) =>
          cards[a.id]!.intervalDays.compareTo(cards[b.id]!.intervalDays));
    add(young);
    add(newWords.take(dailyNew * 3));
    if (out.isEmpty) add(studyPool.take(size));
    return out;
  }
}
