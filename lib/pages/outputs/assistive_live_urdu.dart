// lib/pages/outputs/assistive_live_urdu.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:flutter/services.dart';

import '../../../data/services/model_service.dart';
import '../../../data/services/tts_service.dart';
import '../../../data/services/camera_pipeline.dart';

const int    _urduYoloInputSize = 320;
const double _urduYoloConf      = 0.30;

const int    _urduDepthH = 336;
const int    _urduDepthW = 280;
const List<double> _urduMean = [0.485, 0.456, 0.406];
const List<double> _urduStd  = [0.229, 0.224, 0.225];

const double _urduScaleX = _urduDepthW / _urduYoloInputSize;
const double _urduScaleY = _urduDepthH / _urduYoloInputSize;

class AssistiveLivePageUrdu extends StatefulWidget {
  const AssistiveLivePageUrdu({super.key});

  @override
  State<AssistiveLivePageUrdu> createState() => _AssistiveLivePageUrduState();
}

class _AssistiveLivePageUrduState extends State<AssistiveLivePageUrdu> {
  final _pipeline = CameraPipeline();

  bool   _busy       = false;
  String _lastSpoken = '';

  List<String> _urduLabels = [];

  // ── Debug state ──────────────────────────────────────────────
  List<Map<String, dynamic>> _lastFused = [];
  int _yoloMs  = 0;
  int _depthMs = 0;
  int _totalMs = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final raw = await rootBundle.loadString('assets/models/labels_urdu.txt');
    _urduLabels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await _pipeline.init(_processFrame);
    if (mounted) setState(() {});
  }

  Future<void> _processFrame(img.Image frame) async {
    if (_busy) return;
    _busy = true;

    final totalWatch = Stopwatch()..start();

    try {
      // 1. YOLO
      final yoloWatch = Stopwatch()..start();
      final detections = _runYolo(frame);
      yoloWatch.stop();

      debugPrint('YOLO detections (ur): ${detections.length}');

      if (detections.isEmpty) {
        if (mounted) setState(() {
          _lastFused = [];
          _yoloMs  = yoloWatch.elapsedMilliseconds;
          _depthMs = 0;
          _totalMs = yoloWatch.elapsedMilliseconds;
        });
        return;
      }

      // 2. Depth
      final depthImage = img.copyResize(
        frame,
        width: _urduDepthW,
        height: _urduDepthH,
      );
      final depthWatch = Stopwatch()..start();
      final depthMap   = await _runDepth(depthImage);
      depthWatch.stop();

      // 3. Fuse
      final fused = _fuseDetectionsWithDepth(detections, depthMap);

      totalWatch.stop();

      if (mounted) setState(() {
        _lastFused = fused;
        _yoloMs  = yoloWatch.elapsedMilliseconds;
        _depthMs = depthWatch.elapsedMilliseconds;
        _totalMs = totalWatch.elapsedMilliseconds;
      });

      // 4. Speak in Urdu
      final speech = _buildSpeechString(fused);
      debugPrint('TTS (ur): $speech');

      if (speech.isNotEmpty && speech != _lastSpoken) {
        _lastSpoken = speech;
        TtsService.instance.speak(speech, langCode: 'ur-PK');
      }
    } catch (e, st) {
      debugPrint('_processFrame (ur) error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  List<Map<String, dynamic>> _runYolo(img.Image image) {
    final interpreter = ModelService.instance.yoloInterpreter!;

    final resized = img.copyResize(
      image,
      width:  _urduYoloInputSize,
      height: _urduYoloInputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        _urduYoloInputSize,
        (y) => List.generate(
          _urduYoloInputSize,
          (x) {
            final p = resized.getPixel(x, y);
            return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
          },
        ),
      ),
    );

    final output = List.generate(
      1,
      (_) => List.generate(300, (_) => List.filled(6, 0.0)),
    );

    interpreter.run(input, output);

    final detections = <Map<String, dynamic>>[];

    for (final row in output[0] as List<List<double>>) {
      final conf = row[4];
      if (conf < _urduYoloConf) continue;

      final x1 = row[0].clamp(0.0, 1.0);
      final y1 = row[1].clamp(0.0, 1.0);
      final x2 = row[2].clamp(0.0, 1.0);
      final y2 = row[3].clamp(0.0, 1.0);

      if (x2 <= x1 || y2 <= y1) continue;
      if ((x2 - x1) < 0.01 || (y2 - y1) < 0.01) continue;

      detections.add({
        'x1':      x1 * _urduYoloInputSize,
        'y1':      y1 * _urduYoloInputSize,
        'x2':      x2 * _urduYoloInputSize,
        'y2':      y2 * _urduYoloInputSize,
        'conf':    conf,
        'classId': row[5].round(),
      });
    }

    detections.sort((a, b) =>
        (b['conf'] as double).compareTo(a['conf'] as double));

    return detections.take(10).toList();
  }

  Future<List<double>> _runDepth(img.Image depthImage) async {
    final session = ModelService.instance.onnxSession!;

    final input = Float32List(1 * 3 * _urduDepthH * _urduDepthW);
    int idx = 0;

    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < _urduDepthH; y++) {
        for (int x = 0; x < _urduDepthW; x++) {
          final p   = depthImage.getPixel(x, y);
          final raw = (c == 0 ? p.r : c == 1 ? p.g : p.b) / 255.0;
          input[idx++] = (raw - _urduMean[c]) / _urduStd[c];
        }
      }
    }

    final tensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, _urduDepthH, _urduDepthW],
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

    for (final o in outputs) o?.release();

    return depthMap;
  }

  List<Map<String, dynamic>> _fuseDetectionsWithDepth(
    List<Map<String, dynamic>> detections,
    List<double> depthMap,
  ) {
    return detections.map((d) {
      int x1 = ((d['x1'] as double) * _urduScaleX).toInt().clamp(0, _urduDepthW - 1);
      int y1 = ((d['y1'] as double) * _urduScaleY).toInt().clamp(0, _urduDepthH - 1);
      int x2 = ((d['x2'] as double) * _urduScaleX).toInt().clamp(0, _urduDepthW - 1);
      int y2 = ((d['y2'] as double) * _urduScaleY).toInt().clamp(0, _urduDepthH - 1);

      const shrink = 0.20;
      final bw = x2 - x1;
      final bh = y2 - y1;
      x1 = (x1 + bw * shrink).toInt().clamp(0, _urduDepthW - 1);
      x2 = (x2 - bw * shrink).toInt().clamp(0, _urduDepthW - 1);
      y1 = (y1 + bh * shrink).toInt().clamp(0, _urduDepthH - 1);
      y2 = (y2 - bh * shrink).toInt().clamp(0, _urduDepthH - 1);

      double dist = -1;

      if (x2 > x1 && y2 > y1) {
        final values = <double>[];
        for (int y = y1; y <= y2; y += 2) {
          for (int x = x1; x <= x2; x += 2) {
            final v = depthMap[y * _urduDepthW + x];
            if (v.isFinite && v > 0 && v < 100) values.add(v);
          }
        }
        if (values.isNotEmpty) {
          values.sort();
          final pIdx = (0.15 * (values.length - 1)).round();
          dist = values[pIdx];
        }
      }

      return {...d, 'distanceMeters': dist};
    }).toList();
  }

  String _buildSpeechString(List<Map<String, dynamic>> detections) {
    if (detections.isEmpty) return '';

    final sorted = [...detections]..sort((a, b) {
        final da = (a['distanceMeters'] as double?) ?? double.infinity;
        final db = (b['distanceMeters'] as double?) ?? double.infinity;
        return da.compareTo(db);
      });

    final parts = <String>[];

    for (final d in sorted.take(3)) {
      final classId = d['classId'] as int;
      final label   = (classId >= 0 && classId < _urduLabels.length)
          ? _urduLabels[classId]
          : 'رکاوٹ';
      final dist  = (d['distanceMeters'] as double?) ?? -1;
      final steps = _metersToSteps(dist);

      parts.add(dist > 0 ? '$label، $steps قدم آگے' : label);
    }

    return '${parts.join('۔ ')}۔';
  }

  int _metersToSteps(double meters) => (meters / 0.75).round();

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
      body: Stack(
        children: [
          // ── Camera feed ─────────────────────────────────────
          CameraPreview(_pipeline.controller!),

          // ── Debug overlay: REMOVE IN PROD! ────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withOpacity(0.65),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timing row — kept in English for readability during testing
                  Text(
                    'YOLO: ${_yoloMs}ms   Depth: ${_depthMs}ms   Total: ${_totalMs}ms',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 4),

                  // Detection rows
                  if (_lastFused.isEmpty)
                    const Text(
                      'کوئی رکاوٹ نہیں ملی',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    )
                  else
                    ..._lastFused.map((d) {
                      final classId = d['classId'] as int;
                      final label   = (classId >= 0 && classId < _urduLabels.length)
                          ? _urduLabels[classId]
                          : 'رکاوٹ';
                      final conf    = ((d['conf'] as double) * 100).toStringAsFixed(1);
                      final dist    = d['distanceMeters'] as double;
                      final steps   = _metersToSteps(dist);
                      final distStr = dist > 0
                          ? '${dist.toStringAsFixed(2)} m  (~$steps قدم)'
                          : 'فاصلہ دستیاب نہیں';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$conf%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$label  ←  $distStr',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}