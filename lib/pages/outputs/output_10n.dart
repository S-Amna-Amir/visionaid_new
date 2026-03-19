import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

class YoloV10Output extends StatefulWidget {
  const YoloV10Output({super.key});

  @override
  State<YoloV10Output> createState() => _YoloV10OutputState();
}

class _YoloV10OutputState extends State<YoloV10Output> {
  final double confThreshold = 0.4;
  final double iouThreshold = 0.5;
  Interpreter? interpreter;
  img.Image? selectedImage;
  List<Detection> detections = [];
  List<String> labels = [];

  // Timing stats
  int _preprocessTime = 0;
  int _inferenceTime = 0;
  int _postprocessTime = 0;
  int _totalTime = 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/models/yolov10n_float16.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Failed to load model: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final raw = await rootBundle.loadString('assets/models/labels.txt');
      labels = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      print('Loaded ${labels.length} labels');
    } catch (e) {
      print('Failed to load labels: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return;

    setState(() => selectedImage = image);
    await _runModel(image);
  }

  Future<void> _runModel(img.Image image) async {
    try {
      final totalStart = DateTime.now();

      // --- Pre-processing ---
      final preprocessStart = DateTime.now();
      final input = _preprocess(image);
      final preprocessEnd = DateTime.now();
      _preprocessTime = preprocessEnd.difference(preprocessStart).inMilliseconds;

      // --- Inference ---
      final output = List.filled(1 * 300 * 6, 0.0).reshape([1, 300, 6]);

      final inferenceStart = DateTime.now();
      interpreter!.run(input, output);
      final inferenceEnd = DateTime.now();
      _inferenceTime = inferenceEnd.difference(inferenceStart).inMilliseconds;

      // --- Post-processing ---
      final postStart = DateTime.now();
      final parsedDetections = _parseOutput(output[0]);
      final filtered = _nms(parsedDetections);

      setState(() {
        detections = filtered;
      });

      final postEnd = DateTime.now();
      _postprocessTime = postEnd.difference(postStart).inMilliseconds;

      // --- Total Time ---
      final totalEnd = DateTime.now();
      _totalTime = totalEnd.difference(totalStart).inMilliseconds;

      print('Times => Pre: ${_preprocessTime}ms, Infer: ${_inferenceTime}ms, Post: ${_postprocessTime}ms, Total: ${_totalTime}ms');
    } catch (e) {
      print('Error running model: $e');
    }
  }

  List _preprocess(img.Image image) {
    final start = DateTime.now();
    final resized = img.copyResize(image, width: 640, height: 640);
    final input = List.generate(1 * 640 * 640 * 3, (_) => 0.0).reshape([1, 640, 640, 3]);

    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final p = resized.getPixel(x, y);
        input[0][y][x][0] = p.r / 255.0;
        input[0][y][x][1] = p.g / 255.0;
        input[0][y][x][2] = p.b / 255.0;
      }
    }
    return input;
  }

  List<Detection> _parseOutput(List<List<double>> output) {
    final detections = <Detection>[];

    for (var i = 0; i < output.length; i++) {
      final pred = output[i];
      final conf = pred[4];
      if (conf < confThreshold) continue;

      final x1 = pred[0] * 640;
      final y1 = pred[1] * 640;
      final x2 = pred[2] * 640;
      final y2 = pred[3] * 640;
      final classId = pred[5].round();

      detections.add(Detection(x1, y1, x2, y2, conf, classId));
    }

    return detections;
  }

  List<Detection> _nms(List<Detection> detections) {
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final result = <Detection>[];

    for (final det in detections) {
      bool keep = true;
      for (final kept in result) {
        if (_iou(det, kept) > iouThreshold) {
          keep = false;
          break;
        }
      }
      if (keep) result.add(det);
    }
    return result;
  }

  double _iou(Detection a, Detection b) {
    final x1 = max(a.x1, b.x1);
    final y1 = max(a.y1, b.y1);
    final x2 = min(a.x2, b.x2);
    final y2 = min(a.y2, b.y2);

    final interArea = max(0, x2 - x1) * max(0, y2 - y1);
    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);
    return interArea / (areaA + areaB - interArea);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YoloV10 Detection'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: selectedImage == null
            ? const Text('No image selected', style: TextStyle(color: Colors.white))
            : Stack(
                children: [
                  Image.memory(Uint8List.fromList(img.encodeJpg(selectedImage!))),
                  ...detections.map((d) => Positioned(
                        left: d.x1,
                        top: d.y1,
                        width: d.x2 - d.x1,
                        height: d.y2 - d.y1,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.greenAccent, width: 2),
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                '${_getLabel(d.classId)} ${(d.confidence * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                        ),
                      )),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Pre: ${_preprocessTime}ms\n'
                        'Infer: ${_inferenceTime}ms\n'
                        'Post: ${_postprocessTime}ms\n'
                        'Total: ${_totalTime}ms',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.greenAccent,
        onPressed: _pickImage,
        child: const Icon(Icons.image, color: Colors.black),
      ),
    );
  }

  String _getLabel(int id) {
    if (labels.isEmpty || id < 0 || id >= labels.length) return 'ID $id';
    return labels[id];
  }
}

class Detection {
  final double x1, y1, x2, y2, confidence;
  final int classId;

  Detection(this.x1, this.y1, this.x2, this.y2, this.confidence, this.classId);
}
