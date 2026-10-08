// Снимки экранов для README:
// CJK_FONT=/путь/NotoSansSC.ttf flutter test test/screenshots_test.dart --update-goldens
// Без CJK_FONT тесты пропускаются: снимки зависят от шрифтов.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuezi/hanzi/hanzi_data.dart';
import 'package:xuezi/main.dart';
import 'package:xuezi/srs/srs.dart';
import 'package:xuezi/state/app_state.dart';
import 'package:xuezi/ui/settings_screen.dart';
import 'package:xuezi/ui/study_screen.dart';
import 'package:xuezi/ui/lesson_screen.dart';
import 'package:xuezi/ui/theme.dart';
import 'package:xuezi/ui/word_card.dart';
import 'package:xuezi/ui/writing_screen.dart';

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(
        ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  if (Platform.environment['CJK_FONT'] == null) return;
  final fonts = Platform.environment['FLUTTER_ROOT'] ??
      '${Directory.current.parent.path}/flutter';
  final mf = '$fonts/bin/cache/artifacts/material_fonts';

  setUpAll(() async {
    // Noto Sans SC покрывает латиницу с тонами, кириллицу и иероглифы.
    final cjk = Platform.environment['CJK_FONT']!;
    await _font('Roboto', [cjk]);
    await _font('MaterialIcons', ['$mf/MaterialIcons-Regular.otf']);
    await _font('Noto Sans CJK SC',
        [cjk]);
  });

  Future<AppState> setup(WidgetTester tester, Map<String, Object> prefs) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(prefs);
    await tester.runAsync(HanziData.ensureLoaded);
    return (await tester.runAsync(AppState.load))!;
  }

  Future<void> seed(WidgetTester tester, AppState s) async {
    await tester.runAsync(() async {
      for (final w in s.studyPool.take(4)) {
        await s.answer(w, Grade.good);
      }
    });
  }

  testWidgets('onboarding', (tester) async {
    final s = await setup(tester, {});
    await tester.pumpWidget(XueziApp(state: s));
    await tester.pumpAndSettle();
    await expectLater(find.byType(XueziApp), matchesGoldenFile('screenshots/1_onboarding.png'));
  });

  testWidgets('today', (tester) async {
    final s = await setup(tester, {'onboarded': true, 'levels': ['1', '2']});
    await seed(tester, s);
    await tester.pumpWidget(XueziApp(state: s));
    await tester.pumpAndSettle();
    await expectLater(find.byType(XueziApp), matchesGoldenFile('screenshots/2_today.png'));
  });

  testWidgets('study', (tester) async {
    final s = await setup(tester, {'onboarded': true});
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: StudyScreen(state: s)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/3_card_front.png'));
    await tester.tap(find.text('Показать пример'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Показать пиньинь и перевод'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/4_card_back.png'));
  });

  testWidgets('dictionary and progress', (tester) async {
    final s = await setup(tester, {'onboarded': true, 'levels': ['1', '2']});
    await seed(tester, s);
    await tester.pumpWidget(XueziApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Словарь').last);
    await tester.pumpAndSettle();
    await expectLater(find.byType(XueziApp), matchesGoldenFile('screenshots/5_dictionary.png'));
    await tester.tap(find.text('Прогресс').last);
    await tester.pumpAndSettle();
    await expectLater(find.byType(XueziApp), matchesGoldenFile('screenshots/6_progress.png'));
  });

  testWidgets('settings', (tester) async {
    final s = await setup(tester, {'onboarded': true});
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: SettingsScreen(state: s)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/7_settings.png'));
  });

  Widget app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: home);

  testWidgets('lessons', (tester) async {
    final s = await setup(tester, {'onboarded': true});
    await tester.pumpWidget(XueziApp(state: s));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Уроки').last);
    await tester.pumpAndSettle();
    await expectLater(find.byType(XueziApp), matchesGoldenFile('screenshots/8_lessons.png'));

    await tester.pumpWidget(app(LessonScreen(state: s, lesson: s.lessons.first)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/9_grammar.png'));
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.lessons.first.dialogue[1].zh).first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/10_dialogue.png'));
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/11_exercise.png'));
  });

  testWidgets('writing and breakdown', (tester) async {
    final s = await setup(tester, {'onboarded': true});
    await tester.pumpWidget(app(WritingScreen(state: s, chars: ['好'])));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/12_writing.png'));

    await tester.pumpWidget(app(Builder(builder: (context) => Scaffold(
          body: TextButton(
              onPressed: () => openWord(context, s.wordByHanzi('汉语')!),
              child: const Text('open')),
        ))));
    await tester.tap(find.text('open'));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('screenshots/13_breakdown.png'));
  });
}
