import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

class ModelService {
  ModelService._();
  static final ModelService instance = ModelService._();

  Interpreter? yoloInterpreter;
  OrtSession? onnxSession;
  List<String> yoloLabels = [];

  bool get isReady => yoloInterpreter != null && onnxSession != null;

  /// Call this once from the splash screen.
  Future<void> loadAll() async {
    await Future.wait([
      _loadYolo(),
      _loadOnnx(),
    ]);
  }

  // ── YOLO ──────────────────────────────────────────────────────────────────
  
  Future<void> _loadYolo2() async {
    yoloInterpreter =
        await Interpreter.fromAsset('assets/models/yolov10n_float16.tflite');

    final raw =
        await rootBundle.loadString('assets/models/labels.txt');
    yoloLabels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  
  Future<void> _loadYolo() async {
    yoloInterpreter =
        await Interpreter.fromAsset('assets/models/best_yolov10n_custom_int8.tflite');

    final raw =
        await rootBundle.loadString('assets/models/labels.txt');
    yoloLabels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ── UniDepth ONNX ─────────────────────────────────────────────────────────

  Future<void> _loadOnnx() async {
    final cacheDir = await getApplicationCacheDirectory();
    final modelDir = Directory('${cacheDir.path}/models');
    await modelDir.create(recursive: true);

    final onnxPath = '${modelDir.path}/test_onnx_lol.onnx';
    final dataPath = '${modelDir.path}/test_onnx_lol.onnx.data';

    await _copyAsset('assets/models/test_onnx_lol.onnx', onnxPath);
    await _copyAsset('assets/models/test_onnx_lol.onnx.data', dataPath);

    onnxSession =
        OrtSession.fromFile(File(onnxPath), OrtSessionOptions());
  }

  Future<void> _copyAsset(String asset, String target) async {
    final data = await rootBundle.load(asset);
    await File(target).writeAsBytes(
      data.buffer.asUint8List(),
      flush: true,
    );
  }
}