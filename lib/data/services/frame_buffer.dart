import 'package:image/image.dart' as img;

/// Holds decoded frames extracted from a video and exposes
/// batch-slicing helpers used by both inference pages.
class FrameBuffer {
  FrameBuffer._();
  static final FrameBuffer instance = FrameBuffer._();

  final List<img.Image> _frames = [];
  bool _isReady = false;

  // ── Public accessors ────────────────────────────────────────────────────────

  bool get isReady => _isReady;
  int get length => _frames.length;
  img.Image operator [](int i) => _frames[i];

  /// Replace the buffer with a fresh set of frames (called after extraction).
  void load(List<img.Image> frames) {
    _frames
      ..clear()
      ..addAll(frames);
    _isReady = _frames.isNotEmpty;
  }

  /// Clear everything (e.g. when a new video is selected).
  void clear() {
    _frames.clear();
    _isReady = false;
  }

  /// Returns consecutive slices of [batchSize] frames.
  /// The last batch may be smaller than [batchSize].
  Iterable<List<img.Image>> batches(int batchSize) sync* {
    for (int i = 0; i < _frames.length; i += batchSize) {
      yield _frames.sublist(
        i,
        (i + batchSize).clamp(0, _frames.length),
      );
    }
  }

  /// Convenience: all frames as an unmodifiable view.
  List<img.Image> get all => List.unmodifiable(_frames);
}