import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../../../data/services/model_service.dart';
import '../../../data/services/tts_service.dart';
import '../../../data/services/camera_pipeline.dart';

class AssistiveLivePage extends StatefulWidget {
  const AssistiveLivePage({super.key});

  @override
  State<AssistiveLivePage> createState() => _AssistiveLivePageState();
}

class _AssistiveLivePageState extends State<AssistiveLivePage> {
  final pipeline = CameraPipeline();

  bool _busy = false;
  String _lastSpoken = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await pipeline.init(_processFrame);
    setState(() {});
  }

  Future<void> _processFrame(img.Image frame) async {
    if (_busy) return;
    _busy = true;

    try {
      // 1️⃣ YOLO Detection
      final detections = _runYolo(frame);

      // 2️⃣ Depth Estimation
      final depth = await _runDepth(frame);

      // 3️⃣ Decision Logic
      final warning = _analyze(detections, depth);

      // 4️⃣ Speak
      if (warning.isNotEmpty && warning != _lastSpoken) {
        _lastSpoken = warning;
        TtsService.instance.speak(warning);
      }

    } catch (e) {
      debugPrint("Error: $e");
    }

    _busy = false;
  }

  // 🔍 YOLO
  List _runYolo(img.Image image) {
    final interpreter = ModelService.instance.yoloInterpreter!;
    // reuse your preprocess logic here
    // (keep your existing YOLO code)
    return [];
  }

  // 🌊 Depth
  Future<List<double>> _runDepth(img.Image image) async {
    final session = ModelService.instance.onnxSession!;
    // reuse your existing depth code
    return [];
  }

  // 🧠 Decision logic
  String _analyze(List detections, List<double> depth) {
    if (detections.isEmpty) return '';

    // Example logic:
    return "Obstacle ahead";
  }

  @override
  void dispose() {
    pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (pipeline.controller == null ||
        !pipeline.controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: CameraPreview(pipeline.controller!),
    );
  }
}