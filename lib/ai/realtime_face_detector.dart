import 'dart:math' as math;
import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'face_embedder.dart';

class RealtimeFaceDetector {
  static const _modelPath = 'lib/assets/yolofacedetect.tflite';
  static const _confidenceThreshold = 0.35;
  static const _iouThreshold = 0.50;
  static const _faceCropPaddingRatio = 0.25;
  static const _inputWidth = 640;
  static const _inputHeight = 640;

  RealtimeFaceDetector({Uint8List? modelBytes}) : _modelBytes = modelBytes;

  final Uint8List? _modelBytes;
  Interpreter? _interpreter;
  String? _modelSummary;

  Future<String> load() async {
    final existing = _interpreter;
    if (existing != null) return _modelSummary ?? 'Model deteksi siap';

    final options = InterpreterOptions()..threads = 2;
    final bytes = _modelBytes;
    final interpreter = bytes == null
        ? await Interpreter.fromAsset(_modelPath, options: options)
        : Interpreter.fromBuffer(bytes, options: options);
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
    final rgbImage = _cameraImageToRgb(image);
    return _detectFacesFromRgb(
      interpreter: interpreter,
      inputTensor: inputTensor,
      outputTensor: outputTensor,
      rgbImage: rgbImage,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
    );
  }

  Future<List<DetectedFaceBox>> detectImage(img.Image image) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Model deteksi wajah belum dimuat');
    }

    return _detectFacesFromRgb(
      interpreter: interpreter,
      inputTensor: interpreter.getInputTensor(0),
      outputTensor: interpreter.getOutputTensor(0),
      rgbImage: image,
      imageWidth: image.width.toDouble(),
      imageHeight: image.height.toDouble(),
    );
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _modelSummary = null;
  }
}

Future<List<DetectedFaceBox>> _detectFacesFromRgb({
  required Interpreter interpreter,
  required dynamic inputTensor,
  required dynamic outputTensor,
  required img.Image rgbImage,
  required double imageWidth,
  required double imageHeight,
}) async {
  final inputShape = inputTensor.shape;
  if (inputShape.length != 4) {
    throw StateError('Shape input model deteksi tidak didukung: $inputShape');
  }

  final isFloatInput =
      inputTensor.type.toString().toLowerCase().contains('float');
  final resized = img.copyResize(
    rgbImage,
    width: RealtimeFaceDetector._inputWidth,
    height: RealtimeFaceDetector._inputHeight,
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
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        inputWidth: RealtimeFaceDetector._inputWidth.toDouble(),
        inputHeight: RealtimeFaceDetector._inputHeight.toDouble(),
      );
    if (box != null) detections.add(box);
  }

  return _nonMaxSuppression(detections)
      .map((box) => box.copyWith(faceImage: _cropFace(rgbImage, box)))
      .toList();
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
  final centerX = box.left + box.width / 2;
  final centerY = box.top + box.height / 2;
  final paddedSize = math.max(box.width, box.height) *
      (1 + RealtimeFaceDetector._faceCropPaddingRatio);
  final halfSize = paddedSize / 2;

  final left = (centerX - halfSize).clamp(0, image.width - 1).toDouble();
  final top = (centerY - halfSize).clamp(0, image.height - 1).toDouble();
  final right = (centerX + halfSize).clamp(left + 1, image.width).toDouble();
  final bottom = (centerY + halfSize).clamp(top + 1, image.height).toDouble();

  final x = left.round().clamp(0, image.width - 1).toInt();
  final y = top.round().clamp(0, image.height - 1).toInt();
  final width = (right - left).round().clamp(1, image.width - x).toInt();
  final height = (bottom - top).round().clamp(1, image.height - y).toInt();
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

class RealtimeAiProcessor {
  static const int targetFps = 1;
  static const double recognitionThreshold = 0.30;
  static const double minRecognizableFaceSize = 80;
  static const int maxAiFrameSide = 480;
  static const int _minFrameIntervalMs = 1000 ~/ targetFps;

  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _receivePort;
  final _pending = <int, Completer<List<AiRecognizedFaceBox>>>{};
  int _nextFrameId = 0;
  bool _isBusy = false;
  DateTime _lastAcceptedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start({
    required List<AiKnownFace> knownFaces,
  }) async {
    if (_workerPort != null) return;

    final yoloModelBytes = await _loadAssetBytes(RealtimeFaceDetector._modelPath);
    final faceModelBytes = await _loadAssetBytes(FaceEmbedder.modelPath);

    _receivePort = ReceivePort();
    final readyCompleter = Completer<void>();
    _receivePort!.listen((message) {
      if (message is Map && message['type'] == 'ready') {
        _workerPort = message['sendPort'] as SendPort;
        if (!readyCompleter.isCompleted) readyCompleter.complete();
        return;
      }
      if (message is Map && message['type'] == 'initError') {
        if (!readyCompleter.isCompleted) {
          readyCompleter.completeError(StateError(message['error'].toString()));
        }
        return;
      }
      _handleWorkerMessage(message);
    });

    final errorPort = ReceivePort();
    errorPort.listen((message) {
      if (!readyCompleter.isCompleted) {
        readyCompleter.completeError(StateError('AI isolate gagal dimulai: $message'));
      }
    });

    _isolate = await Isolate.spawn(
      _aiWorkerEntry,
      {
        'sendPort': _receivePort!.sendPort,
        'yoloModel': TransferableTypedData.fromList([yoloModelBytes]),
        'faceModel': TransferableTypedData.fromList([faceModelBytes]),
        'knownFaces': knownFaces.map((face) => face.toMap()).toList(),
      },
      debugName: 'presensi-ai-worker',
      onError: errorPort.sendPort,
    );

    try {
      await readyCompleter.future.timeout(const Duration(seconds: 45));
    } finally {
      errorPort.close();
    }
  }

  Future<Uint8List> _loadAssetBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<List<AiRecognizedFaceBox>?> processFrame(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    final now = DateTime.now();
    if (_isBusy ||
        now.difference(_lastAcceptedAt).inMilliseconds < _minFrameIntervalMs) {
      return null;
    }

    final port = _workerPort;
    if (port == null) return null;

    _isBusy = true;
    _lastAcceptedAt = now;
    final frameId = _nextFrameId++;
    final completer = Completer<List<AiRecognizedFaceBox>>();
    _pending[frameId] = completer;

    port.send({
      'type': 'frame',
      'id': frameId,
      'width': image.width,
      'height': image.height,
      'rotationDegrees': rotationDegrees,
      'format': image.format.group.name,
      'planes': image.planes
          .map((plane) => TransferableTypedData.fromList([plane.bytes]))
          .toList(),
      'bytesPerRow': image.planes.map((plane) => plane.bytesPerRow).toList(),
      'bytesPerPixel':
          image.planes.map((plane) => plane.bytesPerPixel ?? 1).toList(),
    });

    try {
      return await completer.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _pending.remove(frameId);
      debugPrint('AI frame timeout: frame $frameId belum selesai diproses');
      return null;
    } finally {
      _isBusy = false;
    }
  }

  void _handleWorkerMessage(dynamic message) {
    if (message is! Map) return;
    if (message['type'] != 'result') return;

    final id = message['id'] as int?;
    if (id == null) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;

    final error = message['error'];
    if (error != null) {
      completer.completeError(StateError(error.toString()));
      return;
    }

    final rawFaces = message['faces'];
    final faces = rawFaces is List
        ? rawFaces
            .map((item) => AiRecognizedFaceBox.fromMap(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList()
        : <AiRecognizedFaceBox>[];
    completer.complete(faces);
  }

  void stop() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(const []);
    }
    _pending.clear();
    _workerPort?.send({'type': 'close'});
    _workerPort = null;
    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _isBusy = false;
  }
}

class AiKnownFace {
  const AiKnownFace({
    required this.siswaId,
    required this.name,
    required this.embedding,
  });

  final int siswaId;
  final String name;
  final List<double> embedding;

  Map<String, dynamic> toMap() {
    return {
      'siswaId': siswaId,
      'name': name,
      'embedding': embedding,
    };
  }
}

class AiRecognizedFaceBox {
  const AiRecognizedFaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.name,
    required this.confidence,
    required this.isRecognized,
    this.siswaId,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String name;
  final double confidence;
  final bool isRecognized;
  final int? siswaId;

  factory AiRecognizedFaceBox.fromMap(Map<String, dynamic> map) {
    return AiRecognizedFaceBox(
      left: (map['left'] as num).toDouble(),
      top: (map['top'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      name: map['name']?.toString() ?? 'Tidak dikenali',
      confidence: (map['confidence'] as num).toDouble(),
      isRecognized: map['isRecognized'] == true,
      siswaId: map['siswaId'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'name': name,
      'confidence': confidence,
      'isRecognized': isRecognized,
      'siswaId': siswaId,
    };
  }
}

Future<void> _aiWorkerEntry(Map<String, dynamic> config) async {
  final mainPort = config['sendPort'] as SendPort;
  final receivePort = ReceivePort();
  final yoloModelBytes =
      (config['yoloModel'] as TransferableTypedData).materialize().asUint8List();
  final faceModelBytes =
      (config['faceModel'] as TransferableTypedData).materialize().asUint8List();
  final detector = RealtimeFaceDetector(modelBytes: yoloModelBytes);
  final embedder = FaceEmbedder(modelBytes: faceModelBytes);
  late final List<_WorkerKnownFace> knownFaces;

  try {
    knownFaces = (config['knownFaces'] as List)
        .map(
          (item) => _WorkerKnownFace.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    await detector.load();
    mainPort.send({
      'type': 'ready',
      'sendPort': receivePort.sendPort,
    });
  } catch (error) {
    mainPort.send({
      'type': 'initError',
      'error': error.toString().replaceFirst('Exception: ', ''),
    });
    receivePort.close();
    return;
  }

  await for (final message in receivePort) {
    if (message is! Map) continue;
    if (message['type'] == 'close') break;
    if (message['type'] != 'frame') continue;

    final id = message['id'] as int;
    try {
      final frame = _WorkerFrame.fromMessage(message);
      final rawRgbImage = _workerFrameToRgb(frame);
      final interpreter = detector._interpreter;
      if (interpreter == null) {
        throw StateError('Model deteksi wajah belum siap');
      }
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      var selectedRotation = 0;
      var rgbImage = rawRgbImage;
      var detections = <DetectedFaceBox>[];

      for (final rotation in _rotationCandidates(frame.rotationDegrees)) {
        final candidateImage = _rotateImage(rawRgbImage, rotation);
        final candidateDetections = await _detectFacesFromRgb(
          interpreter: interpreter,
          inputTensor: inputTensor,
          outputTensor: outputTensor,
          rgbImage: candidateImage,
          imageWidth: candidateImage.width.toDouble(),
          imageHeight: candidateImage.height.toDouble(),
        );
        selectedRotation = rotation;
        rgbImage = candidateImage;
        detections = candidateDetections;
        if (detections.isNotEmpty) break;
      }

      debugPrint(
        'YOLO deteksi wajah: ${detections.length} frame=${frame.width}x${frame.height} sensorRot=${frame.rotationDegrees} usedRot=$selectedRotation rgb=${rgbImage.width}x${rgbImage.height}',
      );

      final recognized = <AiRecognizedFaceBox>[];
      for (final box in detections) {
        if (math.min(box.width, box.height) <
            RealtimeAiProcessor.minRecognizableFaceSize) {
          recognized.add(
            AiRecognizedFaceBox(
              left: box.left,
              top: box.top,
              width: box.width,
              height: box.height,
              name: 'Tidak dikenali',
              confidence: 0,
              isRecognized: false,
              siswaId: null,
            ),
          );
          continue;
        }
        final crop = box.faceImage;
        final match = crop == null
            ? null
            : _bestKnownFace(await embedder.embedImage(crop), knownFaces);
        final isRecognized = match != null &&
            match.score >= RealtimeAiProcessor.recognitionThreshold;
        recognized.add(
          AiRecognizedFaceBox(
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
            name: isRecognized ? match!.name : 'Tidak dikenali',
            confidence: match?.score ?? 0,
            isRecognized: isRecognized,
            siswaId: isRecognized ? match.siswaId : null,
          ),
        );
      }

      mainPort.send({
        'type': 'result',
        'id': id,
        'faces': recognized.map((face) => face.toMap()).toList(),
      });
    } catch (error) {
      mainPort.send({
        'type': 'result',
        'id': id,
        'error': error.toString().replaceFirst('Exception: ', ''),
      });
    }
  }

  detector.close();
  embedder.close();
  receivePort.close();
}

_WorkerFaceMatch? _bestKnownFace(
  List<double> probe,
  List<_WorkerKnownFace> knownFaces,
) {
  _WorkerFaceMatch? best;
  var bestScore = -1.0;
  for (final face in knownFaces) {
    final score = _cosineSimilarity(probe, face.embedding);
    if (score > bestScore) {
      bestScore = score;
      best = _WorkerFaceMatch(
        siswaId: face.siswaId,
        name: face.name,
        score: score,
      );
    }
  }
  if (best != null) {
    debugPrint(
      'Face match terbaik: ${best.name} skor=${bestScore.toStringAsFixed(3)} threshold=${RealtimeAiProcessor.recognitionThreshold}',
    );
  }
  return best;
}

class _WorkerKnownFace {
  const _WorkerKnownFace({
    required this.siswaId,
    required this.name,
    required this.embedding,
  });

  final int siswaId;
  final String name;
  final List<double> embedding;

  factory _WorkerKnownFace.fromMap(Map<String, dynamic> map) {
    return _WorkerKnownFace(
      siswaId: map['siswaId'] as int,
      name: map['name']?.toString() ?? 'Siswa',
      embedding: (map['embedding'] as List)
          .map((item) => (item as num).toDouble())
          .toList(),
    );
  }
}

double _cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return -1;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denominator = math.sqrt(normA) * math.sqrt(normB);
  if (denominator == 0) return -1;
  return dot / denominator;
}

img.Image _workerFrameToRgb(_WorkerFrame frame) {
  if (frame.format != ImageFormatGroup.yuv420.name || frame.planes.length < 3) {
    throw StateError('Format kamera harus YUV420 untuk model deteksi wajah');
  }

  final scale = math.min(
    1.0,
    RealtimeAiProcessor.maxAiFrameSide / math.max(frame.width, frame.height),
  );
  final outWidth = math.max(1, (frame.width * scale).round());
  final outHeight = math.max(1, (frame.height * scale).round());
  final out = img.Image(width: outWidth, height: outHeight);
  final yPlane = frame.planes[0];
  final uPlane = frame.planes[1];
  final vPlane = frame.planes[2];

  for (var y = 0; y < outHeight; y++) {
    final sourceY = math.min(frame.height - 1, (y / scale).floor());
    final yRow = sourceY * frame.bytesPerRow[0];
    final uvRow = (sourceY >> 1) * frame.bytesPerRow[1];
    for (var x = 0; x < outWidth; x++) {
      final sourceX = math.min(frame.width - 1, (x / scale).floor());
      final uvIndex = uvRow + (sourceX >> 1) * frame.bytesPerPixel[1];
      final yp = yPlane[yRow + sourceX].toDouble();
      final up = uPlane[uvIndex].toDouble() - 128.0;
      final vp = vPlane[uvIndex].toDouble() - 128.0;

      final red = (yp + 1.402 * vp).round().clamp(0, 255);
      final green = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
      final blue = (yp + 1.772 * up).round().clamp(0, 255);
      out.setPixelRgb(x, y, red, green, blue);
    }
  }

  return out;
}

List<int> _rotationCandidates(int rotationDegrees) {
  final normalizedRotation = rotationDegrees % 360;
  final inverseRotation = (360 - normalizedRotation) % 360;
  if (normalizedRotation == inverseRotation) return [normalizedRotation];
  return [normalizedRotation, inverseRotation];
}

img.Image _rotateImage(img.Image image, int rotationDegrees) {
  final normalizedRotation = rotationDegrees % 360;
  if (normalizedRotation == 0) return image;
  return img.copyRotate(image, angle: normalizedRotation);
}

class _WorkerFrame {
  const _WorkerFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.rotationDegrees,
    required this.planes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final int width;
  final int height;
  final String format;
  final int rotationDegrees;
  final List<Uint8List> planes;
  final List<int> bytesPerRow;
  final List<int> bytesPerPixel;

  factory _WorkerFrame.fromMessage(Map message) {
    return _WorkerFrame(
      width: message['width'] as int,
      height: message['height'] as int,
      format: message['format'] as String,
      rotationDegrees: message['rotationDegrees'] as int? ?? 0,
      planes: (message['planes'] as List)
          .map(
            (item) =>
                (item as TransferableTypedData).materialize().asUint8List(),
          )
          .toList(),
      bytesPerRow: List<int>.from(message['bytesPerRow'] as List),
      bytesPerPixel: List<int>.from(message['bytesPerPixel'] as List),
    );
  }
}

class _WorkerFaceMatch {
  const _WorkerFaceMatch({
    required this.siswaId,
    required this.name,
    required this.score,
  });

  final int siswaId;
  final String name;
  final double score;
}
