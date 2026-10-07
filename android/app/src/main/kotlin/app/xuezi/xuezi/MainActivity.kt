package app.xuezi.xuezi

import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Озвучка встроенным синтезатором речи Android.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "xuezi/speech")
            .setMethodCallHandler { call, result ->
                if (call.method == "speak") {
                    speak(call.argument<String>("text") ?: "")
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun speak(text: String) {
        val engine = tts
        if (engine == null) {
            pending = text
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.SIMPLIFIED_CHINESE
                    tts?.setSpeechRate(0.8f)
                    ttsReady = true
                    pending?.let { say(it) }
                    pending = null
                }
            }
        } else if (ttsReady) {
            say(text)
        } else {
            pending = text
        }
    }

    private fun say(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "xuezi")
    }

    override fun onDestroy() {
        tts?.shutdown()
        super.onDestroy()
    }
}
