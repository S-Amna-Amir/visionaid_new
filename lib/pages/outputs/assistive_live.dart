// lib/pages/assistive_live_page.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';

import '../../../data/services/model_service.dart';
import '../../../data/services/tts_service.dart';
import '../../../data/services/camera_pipeline.dart';

const int    _yoloInputSize = 320;
const double _yoloConf      = 0.30;

const int    _depthH = 336;
const int    _depthW = 280;
const List<double> _mean = [0.485, 0.456, 0.406];
const List<double> _std  = [0.229, 0.224, 0.225];

// Scale from YOLO-space (320×320) → depth-space (280×336)
const double _scaleX = _depthW / _yoloInputSize; // 280/320
const double _scaleY = _depthH / _yoloInputSize; // 336/320

// ─────────────────────────────────────────────────────────────

class AssistiveLivePage extends StatefulWidget {
  const AssistiveLivePage({super.key});

  @override
  State<AssistiveLivePage> createState() => _AssistiveLivePageState();
}

class _AssistiveLivePageState extends State<AssistiveLivePage> {
  final _pipeline = CameraPipeline();

  bool   _busy        = false;
  String _lastSpoken  = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Models are already loaded by the splash screen 
    await _pipeline.init(_processFrame);
    setState(() {});
  }

  // ── Main frame handler ───────────────────────────────────────
  Future<void> _processFrame(img.Image frame) async {
    if (_busy) return;
    _busy = true;

    try {
      // 1. Run YOLO (320×320 model)
      final detections = _runYolo(frame);
      debugPrint('YOLO detections: ${detections.length}');

      if (detections.isEmpty) return;

      // 2. Run depth on a 210×280 resize of the frame
      final depthImage = img.copyResize(frame, width: _depthW, height: _depthH);
      final depthMap   = await _runDepth(depthImage);
      debugPrint('Depth map length: ${depthMap.length}');

      // 3. Fuse: scale YOLO boxes → depth-space, sample depth
      final fused = _fuseDetectionsWithDepth(detections, depthMap);

      // 4. Build TTS string and speak if changed
      final speech = _buildSpeechString(fused);
      debugPrint('TTS: $speech');

      if (speech.isNotEmpty && speech != _lastSpoken) {
        _lastSpoken = speech;
        TtsService.instance.speak(speech);
      }
    } catch (e, st) {
      debugPrint('_processFrame error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  // ── YOLO (320 input) ────────────────
  List<Map<String, dynamic>> _runYolo(img.Image image) {
    final interpreter = ModelService.instance.yoloInterpreter!;

    final resized = img.copyResize(
      image,
      width:  _yoloInputSize,
      height: _yoloInputSize,
      interpolation: img.Interpolation.linear,
    );

    // Build [1, 320, 320, 3] input
    final input = List.generate(
      1,
      (_) => List.generate(
        _yoloInputSize,
        (y) => List.generate(
          _yoloInputSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          },
        ),
      ),
    );

    // Output: [1, 300, 6] → [x1, y1, x2, y2, conf, classId] (normalised 0–1)
    final output = List.generate(
      1,
      (_) => List.generate(300, (_) => List.filled(6, 0.0)),
    );

    interpreter.run(input, output);

    final detections = <Map<String, dynamic>>[];

    for (final row in output[0] as List<List<double>>) {
      final conf = row[4];
      if (conf < _yoloConf) continue;

      final x1 = row[0].clamp(0.0, 1.0);
      final y1 = row[1].clamp(0.0, 1.0);
      final x2 = row[2].clamp(0.0, 1.0);
      final y2 = row[3].clamp(0.0, 1.0);

      if (x2 <= x1 || y2 <= y1) continue;
      if ((x2 - x1) < 0.01 || (y2 - y1) < 0.01) continue;

      // Convert normalised → pixel coords in YOLO-space (320×320)
      detections.add({
        'x1':      x1 * _yoloInputSize,
        'y1':      y1 * _yoloInputSize,
        'x2':      x2 * _yoloInputSize,
        'y2':      y2 * _yoloInputSize,
        'conf':    conf,
        'classId': row[5].round(),
      });
    }

    detections.sort((a, b) =>
        (b['conf'] as double).compareTo(a['conf'] as double));

    return detections.take(10).toList();
  }

  // ── Depth (ONNX model, 210×280 input) ─────────────
  Future<List<double>> _runDepth(img.Image depthImage) async {
    final session = ModelService.instance.onnxSession!;

    final input = Float32List(1 * 3 * _depthH * _depthW);
    int idx = 0;

    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < _depthH; y++) {
        for (int x = 0; x < _depthW; x++) {
          final p   = depthImage.getPixel(x, y);
          final raw = (c == 0 ? p.r : c == 1 ? p.g : p.b) / 255.0;
          input[idx++] = (raw - _mean[c]) / _std[c];
        }
      }
    }

    final tensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, _depthH, _depthW],
    );

    final outputs = await session.runAsync(OrtRunOptions(), {'input': tensor});
    tensor.release();

    final raw = (outputs!.first as OrtValueTensor).value;

    final List<double> depthMap;
    if (raw is List<List<List<List<double>>>>) {
      depthMap = raw[0][0].expand((r) => r).toList();
    } else if (raw is List<List<List<double>>>) {
      depthMap = raw[0].expand((r) => r).toList();
    } else if (raw is List<List<double>>) {
      depthMap = raw.expand((r) => r).toList();
    } else {
      depthMap = (raw as List).cast<double>();
    }

    for (final o in outputs) {
      o?.release();
    }

    return depthMap;
  }

  // ── Fuse YOLO boxes with depth map ───────────────────────────
  List<Map<String, dynamic>> _fuseDetectionsWithDepth(
    List<Map<String, dynamic>> detections,
    List<double> depthMap,
  ) {
    return detections.map((d) {
      // Scale YOLO-space → depth-space
      int x1 = ((d['x1'] as double) * _scaleX).toInt().clamp(0, _depthW - 1);
      int y1 = ((d['y1'] as double) * _scaleY).toInt().clamp(0, _depthH - 1);
      int x2 = ((d['x2'] as double) * _scaleX).toInt().clamp(0, _depthW - 1);
      int y2 = ((d['y2'] as double) * _scaleY).toInt().clamp(0, _depthH - 1);

      // Shrink 20% to reduce background contamination
      const shrink = 0.20;
      final bw = x2 - x1;
      final bh = y2 - y1;
      x1 = (x1 + bw * shrink).toInt().clamp(0, _depthW - 1);
      x2 = (x2 - bw * shrink).toInt().clamp(0, _depthW - 1);
      y1 = (y1 + bh * shrink).toInt().clamp(0, _depthH - 1);
      y2 = (y2 - bh * shrink).toInt().clamp(0, _depthH - 1);

      double dist = -1;

      if (x2 > x1 && y2 > y1) {
        final values = <double>[];
        for (int y = y1; y <= y2; y += 2) {
          for (int x = x1; x <= x2; x += 2) {
            final v = depthMap[y * _depthW + x];
            if (v.isFinite && v > 0 && v < 100) values.add(v);
          }
        }
        if (values.isNotEmpty) {
          values.sort();
          final pIdx = (0.15 * (values.length - 1)).round(); // 15th percentile
          dist = values[pIdx];
        }
      }

      return {...d, 'distanceMeters': dist};
    }).toList();
  }

  // ── Build spoken string ───────────────────────────────────────
  // Format: "person, 1.5 meters ahead. car, 3.2 meters ahead."
  // Sorted closest-first, capped at 3 objects to keep audio brief.
  String _buildSpeechString(List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) return '';

    final labels = ModelService.instance.yoloLabels; // ← loaded in splash

    final sorted = [...detections]..sort((a, b) {
        final da = (a['distanceMeters'] as double?) ?? double.infinity;
        final db = (b['distanceMeters'] as double?) ?? double.infinity;
        return da.compareTo(db);
      });

    final parts = <String>[];

    for (final d in sorted.take(3)) {
      final classId = d['classId'] as int;
      final label   = (classId >= 0 && classId < labels.length)
          ? labels[classId]
          : 'object';
      final dist = (d['distanceMeters'] as double?) ?? -1;

      parts.add(dist > 0
          ? '$label, ${dist.toStringAsFixed(1)} meters ahead'
          : label);
    }

    return '${parts.join('. ')}.';
  }

  // ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pipeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pipeline.controller == null ||
        !_pipeline.controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: CameraPreview(_pipeline.controller!),
    );
  }
}