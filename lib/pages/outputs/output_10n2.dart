import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class YoloPage extends StatefulWidget {
  const YoloPage({super.key});

  @override
  State<YoloPage> createState() => _YoloPageState();
}

class _YoloPageState extends State<YoloPage> {
  Interpreter? interpreter;
  List<String> labels = [];

  img.Image? pickedImage;

  String status = 'Loading model...';

  String preprocessTime = '';
  String inferenceTime = '';
  String postprocessTime = '';
  String totalTime = '';

  int detectionCount = 0;

  bool loading = false;

  static const int inputSize = 320;
  static const double confThreshold = 0.30;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  // ---------------- LOAD MODEL ----------------

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset(
        'assets/models/best_yolov10n_custom_int8.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      final labelData =
          await rootBundle.loadString('assets/models/labels.txt');

      labels = labelData
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();

      setState(() => status = '✅ Model loaded');
    } catch (e) {
      setState(() => status = '❌ Model load failed: $e');
    }
  }

  // ---------------- IMAGE PICK ----------------

  Future<void> pickAndRun() async {
    if (interpreter == null) return;

    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() {
      loading = true;
      status = 'Running detection...';
      preprocessTime = '';
      inferenceTime = '';
      postprocessTime = '';
      totalTime = '';
      detectionCount = 0;
    });

    try {
      final totalSW = Stopwatch()..start();

      final image =
          img.decodeImage(await File(file.path).readAsBytes())!;
      pickedImage = image;

      final detections = await runModel(image);

      detectionCount = detections.length;

      totalSW.stop();
      totalTime = '${totalSW.elapsedMilliseconds} ms';

      setState(() => status =
          detectionCount == 0
              ? 'No objects detected'
              : '$detectionCount object(s) detected');
    } catch (e) {
      setState(() => status = '❌ Inference failed: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ---------------- PREPROCESS ----------------

  List preprocess(img.Image image) {
    final sw = Stopwatch()..start();

    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final bytes = resized.getBytes();

    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final idx = (y * inputSize + x) * 4;
          return [
            bytes[idx] / 255.0,
            bytes[idx + 1] / 255.0,
            bytes[idx + 2] / 255.0,
          ];
        }),
      ),
    );

    sw.stop();
    preprocessTime = '${sw.elapsedMilliseconds} ms';

    return input;
  }

  // ---------------- INFERENCE + POSTPROCESS ----------------

  Future<List<Map<String, dynamic>>> runModel(img.Image image) async {
    final input = preprocess(image);

    final output = List.generate(
      1,
      (_) => List.generate(300, (_) => List.filled(6, 0.0)),
    );

    final inferSW = Stopwatch()..start();
    interpreter!.run(input, output);
    inferSW.stop();

    inferenceTime = '${inferSW.elapsedMilliseconds} ms';

    final postSW = Stopwatch()..start();

    final detections = <Map<String, dynamic>>[];

    for (final row in output[0]) {
      final x1 = row[0];
      final y1 = row[1];
      final x2 = row[2];
      final y2 = row[3];
      final score = row[4];
      final classId = row[5].round();

      if (score < confThreshold) continue;
      if (classId < 0 || classId >= labels.length) continue;

      final cx1 = x1.clamp(0.0, 1.0);
      final cy1 = y1.clamp(0.0, 1.0);
      final cx2 = x2.clamp(0.0, 1.0);
      final cy2 = y2.clamp(0.0, 1.0);

      if (cx2 <= cx1 || cy2 <= cy1) continue;

      detections.add({
        'label': labels[classId],
        'score': score,
      });
    }

    detections.sort(
        (a, b) => (b['score'] as double).compareTo(a['score']));

    postSW.stop();
    postprocessTime = '${postSW.elapsedMilliseconds} ms';

    return detections.take(10).toList();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOLOv10')),
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

            if (detectionCount > 0)
              Text('Detections: $detectionCount'),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: loading ? null : pickAndRun,
              child: const Text('Pick Image'),
            ),

            const SizedBox(height: 16),

            if (pickedImage != null)
              Image.memory(
                Uint8List.fromList(img.encodeJpg(pickedImage!)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    interpreter?.close();
    super.dispose();
  }
}
