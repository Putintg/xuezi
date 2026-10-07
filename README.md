# Сюэцзы (学字)

Приложение для ежедневного изучения китайских иероглифов. Слова появляются
на экране блокировки и в виджете на рабочем столе, а повторения строятся по
интервальному алгоритму.

<p>
<img src="test/screenshots/2_today.png" width="200">
<img src="test/screenshots/4_card_back.png" width="200">
<img src="test/screenshots/5_dictionary.png" width="200">
<img src="test/screenshots/6_progress.png" width="200">
</p>

## Что умеет

- **Иероглиф дня**: пиньинь, перевод на русский, пример с переводом, озвучка.
- **Экран блокировки**: уведомления со словом по расписанию (каждые 30 мин, 1, 2 или 3 часа, в выбранные часы). Нажатие открывает карточку слова.
- **Виджеты**: на Android на рабочем столе, на iPhone на рабочем столе и на экране блокировки (iOS 16+). Слово меняется само в течение дня, даже когда приложение закрыто.
- **Интервальное повторение** (упрощённый SM-2): кнопки «Снова / Трудно / Хорошо / Легко» с подсказкой следующего интервала.
- **HSK 1–4**: 1193 слова, выбор уровней и количества новых слов в день.
- **Прогресс**: серия дней, прогресс по уровням, календарь занятий.
- **Словарь** с поиском по иероглифу, пиньиню (можно без тонов) и переводу.
- Тёмная тема, онбординг с выбором уровня и темпа.

## Как собрать

Нужны Flutter 3.47+ (stable) и Android Studio (Android SDK).

```bash
flutter pub get
flutter run                 # на подключённом телефоне или эмуляторе
flutter build apk --release # APK: build/app/outputs/flutter-apk/app-release.apk
```

Без своей среды: загрузите проект в репозиторий GitHub, и workflow
`.github/workflows/build-apk.yml` соберёт APK (вкладка Actions, Build APK,
Artifacts).

### iPhone

Нужен Mac с Xcode 16+ или GitHub Actions (`.github/workflows/build-ios.yml`
собирает неподписанный `xuezi-unsigned.ipa`).

- **Mac + Xcode**: откройте `ios/Runner.xcworkspace`, у целей Runner и
  HanziWidget выберите свою команду (Signing & Capabilities) и запустите на
  подключённом iPhone. Бесплатного Apple ID хватает, приложение работает 7 дней,
  потом его нужно переустановить.
- **Windows или Mac без Xcode**: скачайте `xuezi-unsigned.ipa` из Actions и
  установите через Sideloadly со своим Apple ID (те же 7 дней).
- **TestFlight / App Store**: нужен Apple Developer Program (99 $ в год).

Если бандл `app.xuezi.xuezi` занят, поменяйте его и App Group
`group.app.xuezi.xuezi` (в `lib/services/lockscreen.dart`,
`ios/HanziWidget/HanziWidget.swift` и двух `.entitlements`).

На iPhone виджет на экран блокировки добавляется так: долгое нажатие на экран
блокировки, «Настроить», «Экран блокировки», «Добавить виджеты», «Сюэцзы».

## Устройство

```
lib/
  main.dart                 вход, навигация
  data/word.dart            модель слова
  srs/srs.dart              алгоритм повторений
  state/app_state.dart      прогресс, настройки, очередь занятия
  services/lockscreen.dart  уведомления на экране блокировки и данные виджета
  services/speech.dart      озвучка (синтезатор речи телефона)
  ui/                       экраны
android/app/src/main/kotlin/.../HanziWidgetProvider.kt  виджет Android
ios/HanziWidget/HanziWidget.swift                       виджеты iOS (WidgetKit)
assets/words.json           словарь
```

## Что дальше

- Порядок черт (данные Make Me a Hanzi, LGPL/Arphic) и тренировка письма.
- Свои списки слов, HSK 3.0, синхронизация между устройствами.
- Кнопки «Знаю / Не знаю» прямо в уведомлении.

## Источники данных

- Списки HSK 2.0: [complete-hsk-vocabulary](https://github.com/drkameleon/complete-hsk-vocabulary) (MIT).
- Английские значения: CC-CEDICT (CC BY-SA 4.0).
- Русские переводы и примеры написаны для этого проекта (сгенерированы ИИ, стоит выборочно проверить).
