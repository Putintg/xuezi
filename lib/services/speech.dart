import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Озвучка через синтезатор речи телефона.
class Speech {
  Speech._();

  static final _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> say(String text) async {
    if (kIsWeb) return;
    try {
      if (!_ready) {
        await _tts.setLanguage('zh-CN');
        await _tts.setSpeechRate(0.4);
        _ready = true;
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
  }
}
