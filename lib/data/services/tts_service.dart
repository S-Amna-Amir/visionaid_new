/* This is a service which allows any page to output from pre-loaded languages, decreasing loading time */

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._privateConstructor();
  static final TtsService instance = TtsService._privateConstructor();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // ---------------------
    // PRELOAD ENGLISH
    // ---------------------
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);

    // ---------------------
    // PRELOAD URDU
    // ---------------------
    // IMPORTANT: Urdu only works with Google engine
    await _tts.setEngine("com.google.android.tts");

    var ok = await _tts.setLanguage("ur-IN");
    if (ok != 1) {
      print("Urdu not supported, fallback to Hindi IN");
      await _tts.setLanguage("hi-IN");
    }

    // Switch engine back to system default for English
    // (otherwise English may sound robotic or not speak)
    await _tts.setEngine("");  // resets to default engine

    _initialized = true;
  }

  Future<void> setLanguage(String langCode) async {
    if (!_initialized) await init();

    // Urdu needs Google engine
    if (langCode.contains("ur")) {
      await _tts.setEngine("com.google.android.tts");
    } else {
      await _tts.setEngine("");
    }

    await _tts.setLanguage(langCode);
  }

  Future<void> speak(String text, {String? langCode}) async {
    if (!_initialized) await init();

    if (langCode != null) {
      await setLanguage(langCode);
    }

    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }
}
