import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
  DateTime _lastRun = DateTime.now();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await pipeline.init(_processFrame);
    setState(() {});
  }

  int _frameCount = 0;

Future<void> _processFrame(img.Image frame) async {
  _frameCount++;

  // 🔒 Prevent overlap
  if (_busy) return;

  final now = DateTime.now();

  //  Run ONLY every 5 seconds (critical)
  if (now.difference(_lastRun).inMilliseconds < 20000) return;

  _lastRun = now;
  _busy = true;

  try {
    debugPrint("Processing frame $_frameCount");

    //  Run depth safely runs in 5000
   // final depth = await _runDepth(frame);

    //debugPrint("Depth done: ${depth.length}");

    
    
    final detections = _runYolo(frame);
    debugPrint("obstacle done: ${detections.length}");

    //final warning = _analyze(detections, depth);
  /*
    if (warning.isNotEmpty && warning != _lastSpoken) {
      _lastSpoken = warning;
      TtsService.instance.speak(warning);
    }
    */
    

  } catch (e) {
    debugPrint("Depth Error: $e");
  } finally {
    // 🔓 ALWAYS release lock
    _busy = false;
  }
}
  // 🔍 YOLO
  List _runYolo(img.Image image) {
  final interpreter = ModelService.instance.yoloInterpreter!;

  const inputSize = 640;

  // Resize
  final resized = img.copyResize(image, width: inputSize, height: inputSize);

  // Prepare input tensor
  final input = List.generate(inputSize * inputSize * 3, (_) => 0.0)
      .reshape([1, inputSize, inputSize, 3]);

  for (int y = 0; y < inputSize; y++) {
    for (int x = 0; x < inputSize; x++) {
      final p = resized.getPixel(x, y);
      input[0][y][x][0] = p.r / 255.0;
      input[0][y][x][1] = p.g / 255.0;
      input[0][y][x][2] = p.b / 255.0;
    }
  }

  // Output buffer
  final output = List.filled(300 * 6, 0.0).reshape([1, 300, 6]);

  interpreter.run(input, output);

  // Parse detections (reuse your logic)
  final detections = [];
  for (final pred in output[0]) {
    if (pred[4] < 0.3) continue;

    detections.add({
      "x1": pred[0],
      "y1": pred[1],
      "x2": pred[2],
      "y2": pred[3],
      "conf": pred[4],
      "class": pred[5].round(),
    });
  }
  debugPrint("Detections: ${detections.length}");
  return detections;
}

  Future<List<double>> _runDepth(img.Image image) async {
  final session = ModelService.instance.onnxSession!;

  const h = 336;
  const w = 280;

  final resized = img.copyResize(image, width: w, height: h);

  final input = Float32List(3 * h * w);

  const mean = [0.485, 0.456, 0.406];
  const std = [0.229, 0.224, 0.225];

  int idx = 0;

  for (int c = 0; c < 3; c++) {
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = resized.getPixel(x, y);
        final v = (c == 0 ? p.r : c == 1 ? p.g : p.b) / 255.0;
        input[idx++] = (v - mean[c]) / std[c];
      }
    }
  }

  final tensor = OrtValueTensor.createTensorWithDataList(
    input,
    [1, 3, h, w],
  );

  final outputs = await session.runAsync(
    OrtRunOptions(),
    {'input': tensor},
  );

  tensor.release();

  final raw = (outputs!.first as OrtValueTensor).value;

  // Flatten (reuse your logic)
  List<double> depth;

  if (raw is List<List<List<List<double>>>>) {
    depth = raw[0][0].expand((r) => r).toList();
  } else if (raw is List<List<List<double>>>) {
    depth = raw[0].expand((r) => r).toList();
  } else if (raw is List<List<double>>) {
    depth = raw.expand((r) => r).toList();
  } else {
    depth = raw;
  }

  for (final o in outputs) {
    o?.release();
  }

  return depth;
}

  String _analyze(List detections, List<double> depth) {
  if (detections.isEmpty || depth.isEmpty) return '';

  // Find center depth (approx distance ahead)
  final centerDepth = depth[depth.length ~/ 2];

  for (var d in detections) {
    if (d["conf"] > 0.6) {
      if (centerDepth < 0.5) {
        return "Stop! Object very close";
      } else if (centerDepth < 1.5) {
        return "Caution! Object ahead";
      } else {
        return "Object detected ahead";
      }
    }
  }

  return '';
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