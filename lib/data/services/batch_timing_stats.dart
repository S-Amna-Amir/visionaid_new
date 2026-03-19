/// Aggregated timing for one full video-inference pass.
class BatchTimingStats {
  /// Per-batch preprocessing times in milliseconds.
  final List<int> preprocessMs;

  /// Per-batch inference times in milliseconds.
  final List<int> inferenceMs;

  /// Per-batch postprocessing times in milliseconds.
  final List<int> postprocessMs;

  /// Wall-clock time for the entire run in milliseconds.
  final int totalMs;

  const BatchTimingStats({
    required this.preprocessMs,
    required this.inferenceMs,
    required this.postprocessMs,
    required this.totalMs,
  });

  // ── Aggregated helpers ────────────────────────────────────────────────────

  int get totalPreprocessMs => preprocessMs.fold(0, (a, b) => a + b);
  int get totalInferenceMs => inferenceMs.fold(0, (a, b) => a + b);
  int get totalPostprocessMs => postprocessMs.fold(0, (a, b) => a + b);

  double get avgPreprocessMs =>
      preprocessMs.isEmpty ? 0 : totalPreprocessMs / preprocessMs.length;
  double get avgInferenceMs =>
      inferenceMs.isEmpty ? 0 : totalInferenceMs / inferenceMs.length;
  double get avgPostprocessMs =>
      postprocessMs.isEmpty ? 0 : totalPostprocessMs / postprocessMs.length;

  int get numBatches => preprocessMs.length;

  @override
  String toString() =>
      'BatchTimingStats(batches=$numBatches, '
      'totalPre=${totalPreprocessMs}ms, '
      'totalInfer=${totalInferenceMs}ms, '
      'totalPost=${totalPostprocessMs}ms, '
      'total=${totalMs}ms)';
}