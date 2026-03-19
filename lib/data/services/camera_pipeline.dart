import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraPipeline {
  CameraController? controller;

  Future<void> init(Function(img.Image) onFrame) async {
    final cameras = await availableCameras();
    controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller!.initialize();

    controller!.startImageStream((CameraImage image) {
      final converted = _convertYUV420(image);
      if (converted != null) {
        onFrame(converted);
      }
    });
  }

  void dispose() {
    controller?.dispose();
  }

  // 🔥 YUV → RGB conversion (critical for ML)
  img.Image? _convertYUV420(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;

      final img.Image rgb = img.Image(width: width, height: height);

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      int uvIndex = 0;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yValue = yPlane.bytes[y * yPlane.bytesPerRow + x];

          final uvRow = (y ~/ 2);
          final uvCol = (x ~/ 2);

          uvIndex = uvRow * uPlane.bytesPerRow + uvCol;

          final uValue = uPlane.bytes[uvIndex];
          final vValue = vPlane.bytes[uvIndex];

          int r = (yValue + 1.403 * (vValue - 128)).round();
          int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round();
          int b = (yValue + 1.770 * (uValue - 128)).round();

          rgb.setPixelRgba(
            x,
            y,
            r.clamp(0, 255),
            g.clamp(0, 255),
            b.clamp(0, 255),
            255,
          );
        }
      }

      return rgb;
    } catch (_) {
      return null;
    }
  }
}