import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Озвучка через синтезатор речи телефона (нативный код в MainActivity и
/// AppDelegate, без сторонних плагинов).
class Speech {
  Speech._();

  static const _channel = MethodChannel('xuezi/speech');

  static Future<void> say(String text) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } catch (e) {
      debugPrint('Speech failed: $e');
    }
  }
}
