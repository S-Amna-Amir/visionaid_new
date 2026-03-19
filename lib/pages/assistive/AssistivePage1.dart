import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../shared/colors.dart';

class InstructionPage extends StatefulWidget {
  final String instructionText;     // Text to speak
  final String nextRoute;           // Route when swiping left
  final String previousRoute;       // Route when swiping right

  const InstructionPage({
    super.key,
    required this.instructionText,
    required this.nextRoute,
    required this.previousRoute,
  });

  @override
  State<InstructionPage> createState() => _InstructionPageState();
}

class _InstructionPageState extends State<InstructionPage> {
  final FlutterTts _tts = FlutterTts();

  bool _isPlaying = false;
  double dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _configureTTS();
    _startInstruction();
  }

  Future<void> _configureTTS() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // Language (English default, adjust if needed)
    await _tts.setLanguage("en-US");
  }

  Future<void> _startInstruction() async {
    setState(() => _isPlaying = true);
    await _tts.speak(widget.instructionText);
  }

  Future<void> _stopInstruction() async {
    await _tts.stop();
    setState(() => _isPlaying = false);
  }

  void _toggleAudio() {
    if (_isPlaying) {
      _stopInstruction();
    } else {
      _startInstruction();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // LONG PRESS → Switch to Urdu version
        onLongPress: () {
          Navigator.pushNamed(context, '/instructions_urdu2'); 
        },

        // Track swipe
        onHorizontalDragStart: (details) {
          dragStartX = details.globalPosition.dx;
        },
        onHorizontalDragEnd: (details) {
          // RIGHT SWIPE → PREVIOUS PAGE
          if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
            Navigator.pushNamed(context, widget.previousRoute);
          }
          // LEFT SWIPE → NEXT PAGE
          else if (details.primaryVelocity != null &&
              details.primaryVelocity! < 0) {
            Navigator.pushNamed(context, widget.nextRoute);
          }
        },

        // Toggle audio on tap
        onTap: _toggleAudio,

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isPlaying ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(
                _isPlaying
                    ? "Tap to Pause Instructions"
                    : "Tap to Play Instructions",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
