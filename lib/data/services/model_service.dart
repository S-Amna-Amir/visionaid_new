import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

class ModelService {
  ModelService._();
  static final ModelService instance = ModelService._();

  Interpreter? yoloInterpreter;
  OrtSession?  onnxSession;
  List<String> yoloLabels = [];

  bool get isReady => yoloInterpreter != null && onnxSession != null;

  // ── YOLO + labels ─────────────────────────────────────────────────────────

  Future<void> loadYolo() async {
    yoloInterpreter = await Interpreter.fromAsset(
      'assets/models/best_yolov10n_custom_int8.tflite',
      options: InterpreterOptions()..threads = 4,
    );

    final raw = await rootBundle.loadString('assets/models/labels.txt');
    yoloLabels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ── Depth ONNX ────────────────────────────────────────────────────────────

  Future<void> loadOnnx() async {
    final cacheDir = await getApplicationCacheDirectory();
    final modelDir = Directory('${cacheDir.path}/models');
    await modelDir.create(recursive: true);

    final onnxPath = '${modelDir.path}/test_onnx_lol.onnx';
    final dataPath = '${modelDir.path}/test_onnx_lol.onnx.data';

    await Future.wait([
      _copyAsset('assets/models/test_onnx_lol.onnx', onnxPath),
      _copyAsset('assets/models/test_onnx_lol.onnx.data', dataPath),
    ]);

    onnxSession = OrtSession.fromFile(File(onnxPath), OrtSessionOptions());
  }

  /// Convenience: load everything at once (e.g. for testing).
  Future<void> loadAll() async {
    await Future.wait([loadYolo(), loadOnnx()]);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _copyAsset(String asset, String target) async {
    final file = File(target);
    // Skip the copy if the file is already cached from a previous launch.
    if (await file.exists()) return;

    final data = await rootBundle.load(asset);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  }
}