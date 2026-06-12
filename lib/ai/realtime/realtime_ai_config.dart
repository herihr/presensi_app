class RealtimeAiConfig {
  const RealtimeAiConfig._();

  static const int targetFps = 1;
  static const Duration initialCameraWarmupDuration = Duration(seconds: 3);
  static const double recognitionThreshold = 0.65;
  static const double minRecognizableFaceSize = 50;
  static const bool enableTimingLogs = false;
}
