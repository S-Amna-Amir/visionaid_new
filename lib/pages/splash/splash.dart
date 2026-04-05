import 'package:flutter/material.dart';
import '../../shared/colors.dart';
import '../../data/services/model_service.dart';
import '../../data/services/tts_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Starting up…';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // ── Step 1: TTS first so every subsequent status can be spoken ──
      await _setStatus('Preparing voices…');

      await TtsService.instance.init(
        onStatus: (msg) => _setStatus(msg, speak: false),
        // sub-steps are shown on screen but not spoken (TTS not ready yet)
      );

      // TTS is now ready — announce that loading is continuing
      await _setStatus(
        'Voices ready. Loading obstacle detector…',
        speak: true,
      );

      // ── Step 2: YOLO + labels ───────────────────────────────────
      await ModelService.instance.loadYolo();
      await _setStatus('Loading depth estimator…', speak: true);

      // ── Step 3: ONNX depth model ────────────────────────────────
      await ModelService.instance.loadOnnx();
      await _setStatus('You are about to proceed to detections. Swipe to return to options at any time.', speak: true); // Display instructions here!

      await Future.delayed(const Duration(milliseconds: 400));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _status = 'Failed to load:\n$e';
      });
      await TtsService.instance
          .speak('Loading failed. Please restart the app.');
      return; // Do NOT navigate on failure
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/pg1');
  }

  /// Update the displayed status and optionally speak it.
  Future<void> _setStatus(String msg, {bool speak = false}) async {
    if (!mounted) return;
    setState(() => _status = msg);
    if (speak) await TtsService.instance.speak(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(
            child: Text(
              'VisionAid',
              style: TextStyle(
                fontSize: 30,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_hasError)
            const CircularProgressIndicator(color: Colors.white)
          else
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _status = 'Retrying…';
                });
                _init();
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}