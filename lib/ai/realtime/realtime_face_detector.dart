import 'dart:typed_data';

import '../shared/yolo_face_detector.dart';
import 'realtime_ai_config.dart';

class RealtimeFaceDetector extends YoloFaceDetector {
  RealtimeFaceDetector({Uint8List? modelBytes})
      : super(
          modelBytes: modelBytes,
          confidenceThreshold: realtimeConfidenceThreshold,
          iouThreshold: realtimeIouThreshold,
          faceCropPaddingRatio: realtimeFaceCropPaddingRatio,
          inputWidth: realtimeInputWidth,
          inputHeight: realtimeInputHeight,
          enableTimingLogs: RealtimeAiConfig.enableTimingLogs,
          profileLabel: 'YOLO realtime',
        );

  static const modelPath = YoloFaceDetector.modelPath;
  static const realtimeConfidenceThreshold = 0.50;
  static const realtimeIouThreshold = 0.50;
  static const realtimeFaceCropPaddingRatio = 0.25;
  static const realtimeInputWidth = RealtimeAiConfig.yoloInputWidth;
  static const realtimeInputHeight = RealtimeAiConfig.yoloInputHeight;
}
