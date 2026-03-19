import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path_provider/path_provider.dart';

class UniDepthPage extends StatefulWidget {
  const UniDepthPage({super.key});

  @override
  State<UniDepthPage> createState() => _UniDepthPageState();
}

class _UniDepthPageState extends State<UniDepthPage> {
  OrtSession? session;
  img.Image? pickedImage;
  img.Image? depthMap;

  String status = 'Loading model...';

  String preprocessTime = '';
  String inferenceTime = '';
  String postprocessTime = '';
  String totalTime = '';

  bool loading = false;

  static const int inputH = 336;
  static const int inputW = 280;

  static const mean = [0.485, 0.456, 0.406];
  static const std = [0.229, 0.224, 0.225];

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // ---------------- LOAD MODEL ----------------

  Future<void> loadModel() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final modelDir = Directory('${cacheDir.path}/models');
      await modelDir.create(recursive: true);

      final onnxPath = '${modelDir.path}/test_onnx_lol.onnx';
      final dataPath = '${modelDir.path}/test_onnx_lol.onnx.data';

      await _copyAsset('assets/models/test_onnx_lol.onnx', onnxPath);
      await _copyAsset('assets/models/test_onnx_lol.onnx.data', dataPath);

      session = OrtSession.fromFile(File(onnxPath), OrtSessionOptions());

      setState(() => status = '✅ Model loaded');
    } catch (e) {
      setState(() => status = '❌ Model load failed: $e');
    }
  }

  Future<void> _copyAsset(String asset, String target) async {
    final data = await rootBundle.load(asset);
    await File(target).writeAsBytes(
      data.buffer.asUint8List(),
      flush: true,
    );
  }

  // ---------------- IMAGE PICK ----------------

  Future<void> pickAndRun() async {
    if (session == null) return;

    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() {
      loading = true;
      status = 'Running inference...';
      preprocessTime = '';
      inferenceTime = '';
      postprocessTime = '';
      totalTime = '';
    });

    try {
      final totalSW = Stopwatch()..start();

      final image =
          img.decodeImage(await File(file.path).readAsBytes())!;
      pickedImage = image;

      final depth = await runDepth(image);
      visualizeDepth(depth);

      totalSW.stop();
      totalTime = '${totalSW.elapsedMilliseconds} ms';

      setState(() => status = '✅ Done');
    } catch (e) {
      setState(() => status = '❌ Inference failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ---------------- PREPROCESS ----------------

  List<double> preprocess(img.Image image) {
    final sw = Stopwatch()..start();

    final resized =
        img.copyResize(image, width: inputW, height: inputH);

    final input = Float32List(1 * 3 * inputH * inputW);
    int idx = 0;

    for (int c = 0; c < 3; c++) {
      for (int h = 0; h < inputH; h++) {
        for (int w = 0; w < inputW; w++) {
          final p = resized.getPixelSafe(w, h);

          double v =
              (c == 0 ? p.r : c == 1 ? p.g : p.b) / 255.0;

          input[idx++] = (v - mean[c]) / std[c];
        }
      }
    }

    sw.stop();
    preprocessTime = '${sw.elapsedMilliseconds} ms';

    return input;
  }

  // ---------------- INFERENCE ----------------

  Future<List<double>> runDepth(img.Image image) async {
    final inputData = preprocess(image);

    final tensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 3, inputH, inputW],
    );

    final inferSW = Stopwatch()..start();

    final outputs = await session!.runAsync(
      OrtRunOptions(),
      {'input': tensor},
    );

    inferSW.stop();
    inferenceTime = '${inferSW.elapsedMilliseconds} ms';

    final postSW = Stopwatch()..start();

    final outputTensor = outputs!.first as OrtValueTensor;
    final raw = outputTensor.value;

    List<double> depth;

    if (raw is List<List<List<List<double>>>>) {
      depth = raw[0][0].expand((r) => r).toList();
    } else if (raw is List<List<List<double>>>) {
      depth = raw[0].expand((r) => r).toList();
    } else if (raw is List<List<double>>) {
      depth = raw.expand((r) => r).toList();
    } else if (raw is List<double>) {
      depth = raw;
    } else {
      throw Exception(
          "Unexpected output shape: ${raw.runtimeType}");
    }

    tensor.release();
    for (final o in outputs) {
      o?.release();
    }

    postSW.stop();
    postprocessTime = '${postSW.elapsedMilliseconds} ms';

    return depth;
  }

  // ---------------- VISUALIZE ----------------

  void visualizeDepth(List<double> depth) {
    final viz =
        img.Image(width: inputW, height: inputH);

    final minV =
        depth.reduce((a, b) => a < b ? a : b);
    final maxV =
        depth.reduce((a, b) => a > b ? a : b);

    for (int h = 0; h < inputH; h++) {
      for (int w = 0; w < inputW; w++) {
        final norm =
            (depth[h * inputW + w] - minV) /
                (maxV - minV + 1e-6);

        final g =
            (norm * 255).toInt().clamp(0, 255);

        viz.setPixelRgba(w, h, g, g, g, 255);
      }
    }

    setState(() => depthMap = viz);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UniDepth ONNX')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(status),

            if (preprocessTime.isNotEmpty)
              Text('Preprocess: $preprocessTime'),

            if (inferenceTime.isNotEmpty)
              Text('Inference: $inferenceTime'),

            if (postprocessTime.isNotEmpty)
              Text('Postprocess: $postprocessTime'),

            if (totalTime.isNotEmpty)
              Text('Total Pipeline: $totalTime'),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: loading ? null : pickAndRun,
              child: const Text('Pick Image'),
            ),

            if (pickedImage != null)
              Image.memory(
                Uint8List.fromList(
                    img.encodePng(pickedImage!)),
              ),

            if (depthMap != null)
              Image.memory(
                Uint8List.fromList(
                    img.encodePng(depthMap!)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    session?.release();
    super.dispose();
  }
}
