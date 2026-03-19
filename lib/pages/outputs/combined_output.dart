/*
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class CombinedOutputPage extends StatefulWidget {
  const CombinedOutputPage({super.key});

  @override
  State<CombinedOutputPage> createState() => _CombinedOutputPageState();
}

class _CombinedOutputPageState extends State<CombinedOutputPage> {
  Uint8List? originalBytes;

  // YOLO
  Interpreter? yoloInterpreter;
  List<dynamic> yoloDetections = [];
  bool isRunningYolo = false;

  // DEPTH
  OrtSession? depthSession;
  Uint8List? depthImageBytes;
  bool isRunningDepth = false;

  bool modelReady = false;

  @override
  void initState() {
    super.initState();
    _loadAllModels();
  }

  Future<void> _loadAllModels() async {
    try {
      // Load YOLO
      yoloInterpreter =
          await Interpreter.fromAsset("assets/models/yolov10n_float16.tflite");

      // Load Depth ONNX
      
      final raw = await rootBundle.load("assets/models/unidepthv2_vits14.onnx");
      depthSession = OrtSession.fromBuffer(
        raw.buffer.asUint8List(),
        OrtSessionOptions(),
      );
      

      onnxInterpreter = await Interpreter.fromAsset("")

      setState(() => modelReady = true);
    } catch (e) {
      debugPrint("Model load error: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => originalBytes = bytes);

    final image = img.decodeImage(bytes);
    if (image == null) return;

    await _runYolo(image);
    await _runDepth(File(picked.path));
  }

  Future<void> _runYolo(img.Image image) async {
    setState(() {
      isRunningYolo = true;
      yoloDetections = [];
    });

    // Preprocess (same as your YOLO page)
    final input = List.generate(1 * 640 * 640 * 3, (_) => 0.0).reshape([1, 640, 640, 3]);
    final resized = img.copyResize(image, width: 640, height: 640);

    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = img.getRed(pixel) / 255.0;
        input[0][y][x][1] = img.getGreen(pixel) / 255.0;
        input[0][y][x][2] = img.getBlue(pixel) / 255.0;
      }
    }

    final output = List.filled(1 * 300 * 6, 0.0).reshape([1, 300, 6]);
    yoloInterpreter!.run(input, output);

    setState(() {
      yoloDetections = output[0];
      isRunningYolo = false;
    });
  }

  Future<void> _runDepth(File file) async {
    if (depthSession == null) return;

    setState(() {
      isRunningDepth = true;
      depthImageBytes = null;
    });

    final raw = await file.readAsBytes();
    final image = img.decodeImage(raw);
    if (image == null) return;

    final resized = img.copyResize(image, width: 392, height: 392);

    final Float32List inputFloats = Float32List(1 * 3 * 392 * 392);
    int idx = 0;

    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < 392; y++) {
        for (int x = 0; x < 392; x++) {
          final p = resized.getPixel(x, y);
          final r = (p >> 16) & 255;
          final g = (p >> 8) & 255;
          final b = p & 255;

          inputFloats[idx++] = (c == 0 ? r : c == 1 ? g : b) / 255.0;
        }
      }
    }

    final String inputName = depthSession!.inputNames.first;

    final inputs = {
      inputName: OrtValueTensor.createTensorWithDataList(
          inputFloats, [1, 3, 392, 392])
    };

    final runOptions = OrtRunOptions();
    final outputs = await depthSession!.runAsync(
        runOptions, inputs, depthSession!.outputNames);
    runOptions.release();

    final depth = outputs.first!.value as Float32List;

    // Convert depth to grayscale PNG
    double minV = depth.reduce((a, b) => a < b ? a : b);
    double maxV = depth.reduce((a, b) => a > b ? a : b);

    final img.Image out = img.Image(392, 392);

    for (int i = 0; i < depth.length; i++) {
      final norm = ((depth[i] - minV) / (maxV - minV))
          .clamp(0.0, 1.0);
      final gray = (norm * 255).round();

      out.setPixel(i % 392, i ~/ 392,
          0xFF000000 | (gray << 16) | (gray << 8) | gray);
    }

    setState(() {
      depthImageBytes = Uint8List.fromList(img.encodePng(out));
      isRunningDepth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Combined Model Output"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: modelReady ? _pickImage : null,
              child: const Text("Select Image"),
            ),

            if (originalBytes != null)
              Image.memory(originalBytes!, height: 250),

            const SizedBox(height: 20),

            // YOLO STATUS
            Text(
              isRunningYolo
                  ? "Running YOLO (Obstacle Detection)…"
                  : "YOLO Output",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (isRunningYolo) const CircularProgressIndicator(),

            if (!isRunningYolo && yoloDetections.isNotEmpty)
              Text("Detections: ${yoloDetections.length}"),

            const SizedBox(height: 20),

            // DEPTH STATUS
            Text(
              isRunningDepth
                  ? "Running Depth Model…"
                  : "Depth Output",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (isRunningDepth) const CircularProgressIndicator(),

            if (depthImageBytes != null)
              Image.memory(depthImageBytes!, height: 300),
          ],
        ),
      ),
    );
  }
}
*/
