import 'package:flutter_tts/flutter_tts.dart';

/// Two separate FlutterTts engines — one for English, one for Urdu.
/// Engine switching on a single instance is unreliable on Android
/// and causes silent failures, so we keep them isolated.
class TtsService {
  TtsService._privateConstructor();
  static final TtsService instance = TtsService._privateConstructor();

  final FlutterTts _enTts = FlutterTts();
  final FlutterTts _urTts = FlutterTts();

  bool _initialized = false;
  bool _urduAvailable = false;

  /// Call once from the splash screen.
  /// [onStatus] receives human-readable progress strings so the splash
  /// can display (and speak) what is currently loading.
  Future<void> init({void Function(String)? onStatus}) async {
    if (_initialized) return;

    // ── English engine (system default) ──────────────────────────
    onStatus?.call('Preparing English voice…');
    await _enTts.setLanguage("en-US");
    await _enTts.setSpeechRate(0.45);
    await _enTts.awaitSpeakCompletion(true);

    // ── Urdu engine (Google TTS) ──────────────────────────────────
    onStatus?.call('Preparing Urdu voice…');
    try {
      await _urTts.setEngine("com.google.android.tts");

      // ur-PK is more commonly bundled offline on Pakistani devices
      int ok = await _urTts.setLanguage("ur-PK");
      if (ok != 1) ok = await _urTts.setLanguage("ur-IN");
      if (ok != 1) {
        await _urTts.setLanguage("hi-IN");
        print("[TTS] Urdu not available — falling back to hi-IN");
      }

      await _urTts.setSpeechRate(0.45);
      await _urTts.awaitSpeakCompletion(true);
      _urduAvailable = true;
    } catch (e) {
      print("[TTS] Urdu engine init failed: $e");
      _urduAvailable = false;
    }

    _initialized = true;
  }

  /// Speak [text] in the given language.
  /// Pass langCode "ur-IN" / "ur-PK" for Urdu, anything else for English.
  Future<void> speak(String text, {String? langCode}) async {
    if (!_initialized) await init();

    // Stop both engines before speaking to avoid overlap
    await stop();

    final isUrdu = langCode != null && langCode.startsWith("ur");

    if (isUrdu && _urduAvailable) {
      await _urTts.speak(text);
    } else {
      if (langCode != null && langCode != "en-US") {
        await _enTts.setLanguage(langCode);
      } else {
        await _enTts.setLanguage("en-US");
      }
      await _enTts.speak(text);
    }
  }

  Future<void> stop() async {
    await Future.wait([
      _enTts.stop(),
      _urTts.stop(),
    ]);
  }

  bool get isUrduAvailable => _urduAvailable;
}