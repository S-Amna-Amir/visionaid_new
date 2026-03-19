import 'package:flutter/material.dart';
import '../../shared/colors.dart';
import 'package:vision_aid/data/services/tts_service.dart';  

class InstructionPageU extends StatefulWidget {
  final String instructionText;
  final String nextRoute;
  final String previousRoute;

  const InstructionPageU({
    super.key,
    required this.instructionText,
    required this.nextRoute,
    required this.previousRoute,
  });

  @override
  State<InstructionPageU> createState() => _InstructionPageUState();
}

class _InstructionPageUState extends State<InstructionPageU> {
  bool _isPlaying = false;
  double dragStartX = 0.0;

  @override
  void initState() {
    super.initState();
    _startInstruction();
  }

  Future<void> _startInstruction() async {
    setState(() => _isPlaying = true);
    await TtsService.instance.speak(
      widget.instructionText,
      langCode: "ur-IN",
    );
  }

  Future<void> _stopInstruction() async {
    await TtsService.instance.stop();
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
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // LONG PRESS → Switch to ENGLISH page
        onLongPress: () {
          Navigator.pushNamed(context, '/instructions2');
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
                    ? "ہدایات کو روکنے کے لیے اسکرین پر کلک کریں۔"
                    : "ہدایات چلانے کے لیے اسکرین پر کلک کریں۔",
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
