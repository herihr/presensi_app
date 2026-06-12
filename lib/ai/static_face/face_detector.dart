import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

import '../shared/face_detection_models.dart';
import '../shared/server_yolo_detector.dart';

class FaceDetector {
  FaceDetector({
    double confidenceThreshold = FaceDetector.confidenceThreshold,
    double iouThreshold = FaceDetector.iouThreshold,
    double faceCropPaddingRatio = FaceDetector.faceCropPaddingRatio,
  }) : _detector = ServerYoloDetector(
          confidenceThreshold: confidenceThreshold,
          iouThreshold: iouThreshold,
          faceCropPaddingRatio: faceCropPaddingRatio,
          timeout: const Duration(seconds: 15),
        );

  static const confidenceThreshold = 0.40;
  static const iouThreshold = 0.60;
  static const faceCropPaddingRatio = 0.25;

  final ServerYoloDetector _detector;

  Future<String> load() async {
    await _detector.load();
    return 'Server YOLO siap';
  }

  Future<img.Image> cropFace(dynamic image) async {
    final faces = await detect(image);
    if (faces.isEmpty) throw Exception('Wajah tidak ditemukan');

    faces.sort((a, b) => b.confidence.compareTo(a.confidence));
    return faces.first.croppedFace;
  }

  Future<List<DetectedFace>> detect(dynamic image) async {
    final decoded = await _decode(image);
    return detectImage(decoded);
  }

  Future<List<DetectedFace>> detectCameraImage(CameraImage image) {
    throw UnsupportedError(
      'Deteksi CameraImage langsung tidak dipakai untuk embedding awal. '
      'Gunakan realtime presensi untuk camera stream.',
    );
  }

  Future<List<DetectedFace>> detectImage(img.Image image) async {
    final faces = await _detector.detectImage(image);
    return faces.map(DetectedFace.fromYolo).toList();
  }

  Future<img.Image> _decode(dynamic image) async {
    if (image is img.Image) return image;

    late final Uint8List bytes;
    if (image is String) {
      bytes = await File(image).readAsBytes();
    } else if (image is File) {
      bytes = await image.readAsBytes();
    } else {
      throw Exception('Format image tidak valid');
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Gagal decode image');
    return decoded;
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
