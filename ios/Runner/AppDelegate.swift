import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Показывать уведомления со словом, даже когда приложение открыто.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Озвучка встроенным синтезатором речи iOS.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "XueziSpeech") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "xuezi/speech", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "speak",
        let args = call.arguments as? [String: Any],
        let text = args["text"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.speak(text)
      result(nil)
    }
    speechChannel = channel
  }

  private func speak(_ text: String) {
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    synthesizer.stopSpeaking(at: .immediate)
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
    synthesizer.speak(utterance)
  }
}
