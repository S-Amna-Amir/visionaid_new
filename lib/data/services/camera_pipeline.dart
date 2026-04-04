import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraPipeline {
  CameraController? controller;

  // Throttle state lives here so the stream callback can check it
  // without allocating anything.
  DateTime _lastProcessed = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _intervalMs = 5000; // match assistive_live.dart

  Future<void> init(Function(img.Image) onFrame) async {
    final cameras = await availableCameras();
    controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller!.initialize();

    controller!.startImageStream((CameraImage cameraImage) {
      // ── Throttle FIRST before any allocation ──────────────────
      final now = DateTime.now();
      if (now.difference(_lastProcessed).inMilliseconds < _intervalMs) return;
      _lastProcessed = now;

      // ── Only convert the frames we actually intend to process ───
      final converted = _convertYUV420(cameraImage);
      if (converted != null) {
        onFrame(converted);
      }
    });
  }

  void dispose() {
    controller?.stopImageStream();
    controller?.dispose();
  }

  img.Image? _convertYUV420(CameraImage image) {
    try {
      final width  = image.width;
      final height = image.height;

      final rgb = img.Image(width: width, height: height);

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;

      final yRowStride  = yPlane.bytesPerRow;
      final uvRowStride = uPlane.bytesPerRow;
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yVal  = yBytes[y * yRowStride + x];
          final uvIdx = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          final uVal  = uBytes[uvIdx] - 128;
          final vVal  = vBytes[uvIdx] - 128;

          final r = (yVal + 1.403 * vVal).round().clamp(0, 255);
          final g = (yVal - 0.344 * uVal - 0.714 * vVal).round().clamp(0, 255);
          final b = (yVal + 1.770 * uVal).round().clamp(0, 255);

          rgb.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      return rgb;
    } catch (e) {
      return null;
    }
  }
}