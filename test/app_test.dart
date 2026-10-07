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
    expect(find.text('План на сегодня'), findsOneWidget);
    expect(find.text('Урок 1: Знакомство'), findsOneWidget);
    expect(find.textContaining('Повторение ·'), findsOneWidget);
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
    expect(find.text('HSK 1'), findsOneWidget);
    expect(find.text('HSK 6', skipOffstage: false), findsOneWidget);
  });

  testWidgets('иероглиф дня открывается в два касания', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final state = (await tester.runAsync(AppState.load))!;
    final w = state.wordOfTheDay(DateTime.now());
    await tester.pumpWidget(XueziApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text(w.pinyin), findsNothing);
    expect(find.text(w.example), findsNothing);

    await tester.tap(find.text(w.hanzi).first);
    await tester.pumpAndSettle();
    expect(find.text(w.example), findsOneWidget);
    expect(find.text(w.pinyin), findsNothing);

    await tester.tap(find.text(w.hanzi).first);
    await tester.pumpAndSettle();
    expect(find.text(w.pinyin), findsOneWidget);
    expect(find.text(w.meaning), findsOneWidget);
  });
}
