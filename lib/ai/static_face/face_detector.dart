import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../shared/yolo_face_detector.dart';

class FaceDetector {
  FaceDetector({
    Uint8List? modelBytes,
    double confidenceThreshold = FaceDetector.confidenceThreshold,
    double iouThreshold = FaceDetector.iouThreshold,
    double faceCropPaddingRatio = FaceDetector.faceCropPaddingRatio,
  }) : _detector = YoloFaceDetector(
          modelBytes: modelBytes,
          confidenceThreshold: confidenceThreshold,
          iouThreshold: iouThreshold,
          faceCropPaddingRatio: faceCropPaddingRatio,
        );

  static const modelPath = YoloFaceDetector.modelPath;
  static const confidenceThreshold = 0.40;
  static const iouThreshold = YoloFaceDetector.defaultIouThreshold;
  static const faceCropPaddingRatio =
      YoloFaceDetector.defaultFaceCropPaddingRatio;

  final YoloFaceDetector _detector;

  Future<String> load() => _detector.load();

  Future<img.Image> cropFace(dynamic image) => _detector.cropFace(image);

  Future<List<DetectedFace>> detect(dynamic image) async {
    final faces = await _detector.detect(image);
    return faces.map(DetectedFace.fromYolo).toList();
  }

  Future<List<DetectedFace>> detectCameraImage(CameraImage image) async {
    final faces = await _detector.detectCameraImage(image);
    return faces.map(DetectedFace.fromYolo).toList();
  }

  Future<List<DetectedFace>> detectImage(img.Image image) async {
    final faces = await _detector.detectImage(image);
    return faces.map(DetectedFace.fromYolo).toList();
  }

  void close() => _detector.close();
}

class DetectedFace {
  const DetectedFace({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.croppedFace,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final double confidence;
  final img.Image croppedFace;

  factory DetectedFace.fromYolo(YoloDetectedFace face) {
    return DetectedFace(
      x: face.x,
      y: face.y,
      width: face.width,
      height: face.height,
      confidence: face.confidence,
      croppedFace: face.croppedFace,
    );
  }
}
