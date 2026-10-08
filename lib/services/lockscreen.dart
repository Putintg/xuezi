import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/word.dart';
import '../state/app_state.dart';

/// Показ слов вне приложения: уведомления на экране блокировки и виджет.
class Lockscreen {
  Lockscreen._();

  static final _notifications = FlutterLocalNotificationsPlugin();
  static const _androidWidget = 'HanziWidgetProvider';
  static const _iosWidget = 'HanziWidget';
  static const _daysAhead = 5;
  // Общая с виджетом группа на iOS; на Android не используется.
  static const _appGroup = 'group.app.xuezi.xuezi';
  // iOS хранит не больше 64 запланированных уведомлений.
  static const _iosMaxPending = 60;

  /// Срабатывает при нажатии на уведомление; payload — иероглифы слова.
  static void Function(String hanzi)? onOpenWord;

  /// Слово из уведомления или виджета, которым запустили закрытое приложение.
  static Future<String?> launchWord() async {
    if (kIsWeb) return null;
    try {
      final h = _wordFromUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
      if (h != null) return h;
    } catch (_) {}
    try {
      final d = await _notifications.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) {
        return d!.notificationResponse?.payload;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> init() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.setAppGroupId(_appGroup);
    }
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Остаётся UTC — уведомления всё равно придут, просто со сдвигом.
    }
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final h = r.payload;
        if (h != null && h.isNotEmpty) onOpenWord?.call(h);
      },
    );
    // Нажатие на виджет, когда приложение уже запущено.
    HomeWidget.widgetClicked.listen((uri) {
      final h = _wordFromUri(uri);
      if (h != null) onOpenWord?.call(h);
    }, onError: (_) {});
  }

  static String? _wordFromUri(Uri? uri) {
    final h = uri?.queryParameters['h'];
    return h == null || h.isEmpty ? null : h;
  }

  /// Запрашивает разрешение на уведомления (Android 13+, iOS).
  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: false) ?? false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'hanzi_lockscreen',
      'Слова на экране блокировки',
      channelDescription: 'Иероглифы в течение дня',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      // Слово видно на экране блокировки целиком, без «скрытого содержимого».
      visibility: NotificationVisibility.public,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.recommendation,
    ),
    iOS: DarwinNotificationDetails(presentSound: false),
  );

  /// Время показов по расписанию из настроек, начиная с текущего момента.
  static List<DateTime> slots(AppState s, DateTime now) {
    final out = <DateTime>[];
    final step = Duration(minutes: s.lockEveryMinutes);
    for (var d = 0; d < _daysAhead; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      var t = day.add(Duration(hours: s.lockStartHour));
      final end = day.add(Duration(hours: s.lockEndHour));
      while (!t.isAfter(end)) {
        if (t.isAfter(now)) out.add(t);
        t = t.add(step);
      }
    }
    return out;
  }

  static String _title(Word w) => '${w.hanzi}  ·  ${w.pinyin}';
  static String _body(Word w) =>
      w.example.isEmpty ? w.meaning : '${w.meaning}\n${w.example}';

  /// Пересоздаёт расписание уведомлений и данные виджета.
  static Future<void> refresh(AppState s) async {
    if (kIsWeb) return;
    final rotation = s.lockscreenRotation();
    await _updateWidget(s, rotation);
    await _notifications.cancelAll();
    if (!s.lockEnabled || rotation.isEmpty) return;

    var times = slots(s, DateTime.now());
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        times.length > _iosMaxPending) {
      times = times.take(_iosMaxPending).toList();
    }
    for (var i = 0; i < times.length; i++) {
      final w = rotation[i % rotation.length];
      await _notifications.zonedSchedule(
        id: i,
        title: _title(w),
        body: _body(w),
        scheduledDate: tz.TZDateTime.from(times[i], tz.local),
        notificationDetails: _details,
        // Неточные будильники не требуют спецразрешения и экономят батарею.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: w.hanzi,
      );
    }
  }

  /// Показывает слово прямо сейчас — для проверки в настройках.
  static Future<void> showNow(Word w) async {
    if (kIsWeb) return;
    await _notifications.show(
      id: 9999,
      title: _title(w),
      body: _body(w),
      notificationDetails: _details,
      payload: w.hanzi,
    );
  }

  static Future<void> _updateWidget(AppState s, List<Word> rotation) async {
    try {
      final data = [
        for (final w in rotation)
          {'h': w.hanzi, 'p': w.pinyin, 'm': w.meaning}
      ];
      await HomeWidget.saveWidgetData<String>('rotation', jsonEncode(data));
      await HomeWidget.saveWidgetData<int>('slotMinutes', s.lockEveryMinutes);
      await HomeWidget.updateWidget(
          androidName: _androidWidget, iOSName: _iosWidget);
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Перерисовать виджет на границе каждого слота, чтобы слово менялось.
        await HomeWidget.scheduleWidgetUpdates(
          slots(s, DateTime.now()).take(48).toList(),
          androidName: _androidWidget,
        );
      }
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }
}
