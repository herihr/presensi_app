import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class RealtimeFaceDetector {
  static const _modelPath = 'lib/assets/yolofacedetect.tflite';
  static const _confidenceThreshold = 0.35;
  static const _iouThreshold = 0.40;

  Interpreter? _interpreter;
  String? _modelSummary;

  Future<String> load() async {
    final existing = _interpreter;
    if (existing != null) return _modelSummary ?? 'Model deteksi siap';

    final options = InterpreterOptions()..threads = 2;
    final interpreter = await Interpreter.fromAsset(_modelPath, options: options);
    _interpreter = interpreter;

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    _modelSummary =
        'Input ${inputTensor.shape.join('x')} -> Output ${outputTensor.shape.join('x')}';

    debugPrint('YOLO Face input name: ${inputTensor.name}');
    debugPrint('YOLO Face input shape: ${inputTensor.shape}');
    debugPrint('YOLO Face input type: ${inputTensor.type}');
    debugPrint('YOLO Face output name: ${outputTensor.name}');
    debugPrint('YOLO Face output shape: ${outputTensor.shape}');
    debugPrint('YOLO Face output type: ${outputTensor.type}');

    return _modelSummary!;
  }

  Future<List<DetectedFaceBox>> detect(CameraImage image) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model deteksi wajah belum dimuat');
    }

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    if (inputShape.length != 4) {
      throw StateError('Shape input model deteksi tidak didukung: $inputShape');
    }

    final inputHeight = inputShape[1];
    final inputWidth = inputShape[2];
    final isFloatInput =
        inputTensor.type.toString().toLowerCase().contains('float');
    final rgbImage = _cameraImageToRgb(image);
    final resized = img.copyResize(
      rgbImage,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );
    final input = _buildInput(resized, isFloatInput);
    final output = _zeros(outputTensor.shape);

    interpreter.run(input, output);

    final rows = _decodeRows(output, outputTensor.shape);
    final detections = <DetectedFaceBox>[];
    for (final row in rows) {
      final box = _decodeBox(
        row,
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        inputWidth: inputWidth.toDouble(),
        inputHeight: inputHeight.toDouble(),
      );
      if (box != null) detections.add(box);
    }

    return _nonMaxSuppression(detections)
        .map((box) => box.copyWith(faceImage: _cropFace(rgbImage, box)))
        .toList();
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _modelSummary = null;
  }
}

img.Image _cameraImageToRgb(CameraImage image) {
  if (image.format.group != ImageFormatGroup.yuv420 || image.planes.length < 3) {
    throw StateError('Format kamera harus YUV420 untuk model deteksi wajah');
  }

  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final out = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    final yRow = y * yPlane.bytesPerRow;
    final uvRow = (y >> 1) * uPlane.bytesPerRow;
    for (var x = 0; x < width; x++) {
      final uvPixelStride = uPlane.bytesPerPixel ?? 1;
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final yp = yPlane.bytes[yRow + x].toDouble();
      final up = uPlane.bytes[uvIndex].toDouble() - 128.0;
      final vp = vPlane.bytes[uvIndex].toDouble() - 128.0;

      final red = (yp + 1.402 * vp).round().clamp(0, 255);
      final green = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
      final blue = (yp + 1.772 * up).round().clamp(0, 255);
      out.setPixelRgb(x, y, red, green, blue);
    }
  }

  return out;
}

dynamic _buildInput(img.Image image, bool isFloatInput) {
  return [
    List.generate(
      image.height,
      (y) => List.generate(
        image.width,
        (x) {
          final pixel = image.getPixel(x, y);
          if (isFloatInput) {
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          }
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        },
      ),
    ),
  ];
}

dynamic _zeros(List<int> shape) {
  if (shape.length == 1) return List<double>.filled(shape.first, 0);
  return List.generate(shape.first, (_) => _zeros(shape.sublist(1)));
}

List<List<double>> _decodeRows(dynamic output, List<int> shape) {
  final flat = <double>[];
  _flatten(output, flat);
  if (shape.length == 2) {
    return _toRows(flat, shape[0], shape[1]);
  }

  if (shape.length != 3 || shape.first != 1) return const [];
  final first = shape[1];
  final second = shape[2];
  if (first <= 20 && second > first) {
    final attrs = first;
    final count = second;
    if (flat.length < attrs * count) return const [];
    return List.generate(
      count,
      (index) => List.generate(attrs, (attr) => flat[attr * count + index]),
    );
  }
  return _toRows(flat, first, second);
}

List<List<double>> _toRows(List<double> flat, int rows, int cols) {
  if (rows <= 0 || cols <= 0 || flat.length < rows * cols) return const [];
  return List.generate(
    rows,
    (row) => flat.sublist(row * cols, row * cols + cols),
  );
}

void _flatten(dynamic value, List<double> out) {
  if (value is List) {
    for (final item in value) {
      _flatten(item, out);
    }
  } else if (value is num) {
    out.add(value.toDouble());
  }
}

DetectedFaceBox? _decodeBox(
  List<double> row, {
  required double imageWidth,
  required double imageHeight,
  required double inputWidth,
  required double inputHeight,
}) {
  if (row.length < 5) return null;

  var confidence = row[4];
  if (row.length > 5) {
    final classConfidence = row.sublist(5).reduce(math.max);
    confidence = math.max(confidence, confidence * classConfidence);
  }
  confidence = _normalizeScore(confidence);
  if (confidence < RealtimeFaceDetector._confidenceThreshold) return null;

  final x = row[0];
  final y = row[1];
  final w = row[2].abs();
  final h = row[3].abs();
  final normalized = [x, y, w, h].every((value) => value >= 0 && value <= 2);

  double left;
  double top;
  double width;
  double height;
  if (normalized) {
    width = w * imageWidth;
    height = h * imageHeight;
    left = (x * imageWidth) - width / 2;
    top = (y * imageHeight) - height / 2;
  } else {
    final scaleX = imageWidth / inputWidth;
    final scaleY = imageHeight / inputHeight;
    width = w * scaleX;
    height = h * scaleY;
    left = (x * scaleX) - width / 2;
    top = (y * scaleY) - height / 2;
  }

  left = left.clamp(0, imageWidth).toDouble();
  top = top.clamp(0, imageHeight).toDouble();
  width = width.clamp(0, imageWidth - left).toDouble();
  height = height.clamp(0, imageHeight - top).toDouble();
  if (width < 12 || height < 12) return null;

  return DetectedFaceBox(
    left: left,
    top: top,
    width: width,
    height: height,
    confidence: confidence,
  );
}

double _normalizeScore(double value) {
  if (value >= 0 && value <= 1) return value;
  return 1 / (1 + math.exp(-value));
}

List<DetectedFaceBox> _nonMaxSuppression(List<DetectedFaceBox> boxes) {
  final sorted = [...boxes]
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  final selected = <DetectedFaceBox>[];

  for (final box in sorted) {
    final overlaps = selected.any(
      (item) => _iou(item, box) > RealtimeFaceDetector._iouThreshold,
    );
    if (!overlaps) selected.add(box);
    if (selected.length >= 8) break;
  }

  return selected;
}

double _iou(DetectedFaceBox a, DetectedFaceBox b) {
  final left = math.max(a.left, b.left);
  final top = math.max(a.top, b.top);
  final right = math.min(a.left + a.width, b.left + b.width);
  final bottom = math.min(a.top + a.height, b.top + b.height);
  final intersection = math.max(0.0, right - left) * math.max(0.0, bottom - top);
  final union = a.width * a.height + b.width * b.height - intersection;
  if (union <= 0) return 0;
  return intersection / union;
}

img.Image _cropFace(img.Image image, DetectedFaceBox box) {
  final x = box.left.round().clamp(0, image.width - 1).toInt();
  final y = box.top.round().clamp(0, image.height - 1).toInt();
  final width = box.width.round().clamp(1, image.width - x).toInt();
  final height = box.height.round().clamp(1, image.height - y).toInt();
  return img.copyCrop(image, x: x, y: y, width: width, height: height);
}

class DetectedFaceBox {
  const DetectedFaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    this.faceImage,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
  final img.Image? faceImage;

  DetectedFaceBox copyWith({img.Image? faceImage}) {
    return DetectedFaceBox(
      left: left,
      top: top,
      width: width,
      height: height,
      confidence: confidence,
      faceImage: faceImage ?? this.faceImage,
    );
  }
}
