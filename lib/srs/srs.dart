/// Интервальное повторение по упрощённому алгоритму SM-2.
enum Grade { again, hard, good, easy }

class CardState {
  int reps;
  int lapses;
  double ease;
  int intervalDays;
  DateTime due;

  CardState({
    this.reps = 0,
    this.lapses = 0,
    this.ease = 2.5,
    this.intervalDays = 0,
    required this.due,
  });

  bool get isLearned => reps > 0;

  /// Слово считается выученным надолго, если интервал не меньше трёх недель.
  bool get isMature => intervalDays >= 21;

  Map<String, dynamic> toJson() => {
        'r': reps,
        'l': lapses,
        'e': ease,
        'i': intervalDays,
        'd': due.millisecondsSinceEpoch,
      };

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
        reps: j['r'] as int,
        lapses: j['l'] as int,
        ease: (j['e'] as num).toDouble(),
        intervalDays: j['i'] as int,
        due: DateTime.fromMillisecondsSinceEpoch(j['d'] as int),
      );
}

DateTime startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

/// Возвращает новое состояние карточки после ответа.
CardState review(CardState? prev, Grade grade, DateTime now) {
  final s = prev ??
      CardState(due: now); // новая карточка
  final today = startOfDay(now);

  if (grade == Grade.again) {
    s.lapses += s.reps > 0 ? 1 : 0;
    s.reps = 0;
    s.intervalDays = 0;
    s.ease = (s.ease - 0.2).clamp(1.3, 3.0);
    // Покажем снова через 10 минут в этой же сессии.
    s.due = now.add(const Duration(minutes: 10));
    return s;
  }

  int interval;
  if (s.reps == 0) {
    interval = switch (grade) { Grade.hard => 1, Grade.good => 1, _ => 4 };
  } else if (s.reps == 1) {
    interval = switch (grade) { Grade.hard => 2, Grade.good => 3, _ => 6 };
  } else {
    final base = s.intervalDays.toDouble();
    interval = switch (grade) {
      Grade.hard => (base * 1.2).round(),
      Grade.good => (base * s.ease).round(),
      _ => (base * s.ease * 1.3).round(),
    };
    if (interval <= s.intervalDays) interval = s.intervalDays + 1;
  }

  s.ease = switch (grade) {
    Grade.hard => (s.ease - 0.15).clamp(1.3, 3.0),
    Grade.easy => (s.ease + 0.15).clamp(1.3, 3.0),
    _ => s.ease,
  };
  s.reps += 1;
  s.intervalDays = interval;
  s.due = today.add(Duration(days: interval));
  return s;
}
