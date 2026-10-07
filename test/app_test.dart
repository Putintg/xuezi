import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuezi/main.dart';
import 'package:xuezi/srs/srs.dart';
import 'package:xuezi/state/app_state.dart';

void main() {
  testWidgets('после онбординга видны иероглиф дня и кнопка занятия',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final state = (await tester.runAsync(AppState.load))!;
    await tester.pumpWidget(XueziApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Иероглиф дня'), findsOneWidget);
    expect(find.textContaining('Начать занятие'), findsOneWidget);
    expect(find.text(state.wordOfTheDay(DateTime.now()).hanzi),
        findsWidgets);
  });

  testWidgets('ответ на карточку уменьшает очередь новых слов',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarded': true, 'dailyNew': 3});
    final state = (await tester.runAsync(AppState.load))!;
    final queue = state.sessionQueue(DateTime.now());
    expect(queue.length, 3);
    await tester.runAsync(() => state.answer(queue.first, Grade.good));
    expect(state.newLeftToday, 2);
    expect(state.learnedTotal, 1);
    expect(state.streak, 1);
  });

  testWidgets('первый запуск показывает онбординг', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = (await tester.runAsync(AppState.load))!;
    await tester.pumpWidget(XueziApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Сюэцзы'), findsWidgets);
    await tester.tap(find.text('Далее'));
    await tester.pumpAndSettle();
    expect(find.text('Какой у вас уровень?'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(4));
  });
}
