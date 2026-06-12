import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../shared/ai_models.dart';
import '../shared/face_detection_models.dart';
import '../shared/face_embedder.dart';
import '../shared/server_yolo_detector.dart';
import 'camera_frame_converter.dart';
import 'realtime_ai_config.dart';
import 'realtime_similarity_service.dart';

Future<void> realtimeAiWorkerEntry(Map<String, dynamic> config) async {
  final mainPort = config['sendPort'] as SendPort;
  final receivePort = ReceivePort();
  final faceModelBytes =
      (config['faceModel'] as TransferableTypedData).materialize().asUint8List();
  const detector = ServerYoloDetector(
    confidenceThreshold: 0.50,
    iouThreshold: 0.50,
    faceCropPaddingRatio: 0.25,
  );
  final embedder = FaceEmbedder(
    modelBytes: faceModelBytes,
    logModelInfo: !RealtimeAiConfig.enableTimingLogs,
  );
  final similarity = const RealtimeSimilarityService();
  late final List<AiKnownFace> knownFaces;

  try {
    knownFaces = (config['knownFaces'] as List)
        .map(
          (item) => AiKnownFace.fromMap(
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
      final frameTotalWatch = Stopwatch()..start();

      final frameDecodeWatch = Stopwatch()..start();
      final frame = RealtimeCameraFrame.fromMessage(message);
      final scanRegion = _ScanRegion.fromMessage(message['scanRegion']);
      frameDecodeWatch.stop();

      final yuvToRgbWatch = Stopwatch()..start();
      final rawRgbImage = cameraFrameToRgb(frame);
      yuvToRgbWatch.stop();

      var selectedRotation = 0;
      var rgbImage = rawRgbImage;
      var detections = <AiRecognizedFaceBox>[];
      var yoloBoxCount = 0;
      var rotateMs = 0;
      var scanCropMs = 0;
      var yoloMs = 0;
      var recognizeMs = 0;
      final timingLines = <String>[];

      for (final rotation in rotationCandidates(frame.rotationDegrees)) {
        final rotateWatch = Stopwatch()..start();
        final candidateImage = rotateImage(rawRgbImage, rotation);
        rotateWatch.stop();

        final scanCropWatch = Stopwatch()..start();
        final scanFrame = _cropToScanRegion(candidateImage, scanRegion);
        scanCropWatch.stop();

        final yoloWatch = Stopwatch()..start();
        final scanDetections = await detector.detectImage(scanFrame.image);
        final candidateDetections = _offsetDetections(
          scanDetections,
          scanFrame.left,
          scanFrame.top,
        );
        yoloWatch.stop();
        if (RealtimeAiConfig.enableTimingLogs) {
          timingLines.add(
            '[YOLO server] networkAndDetect=${yoloWatch.elapsedMilliseconds}ms, '
            'boxes=${candidateDetections.length}',
          );
        }

        final recognizeWatch = Stopwatch()..start();
        final candidateRecognized = await _recognizeDetections(
          detections: candidateDetections,
          embedder: embedder,
          knownFaces: knownFaces,
          similarity: similarity,
        );
        recognizeWatch.stop();

        selectedRotation = rotation;
        rgbImage = candidateImage;
        detections = candidateRecognized;
        yoloBoxCount = candidateDetections.length;
        rotateMs += rotateWatch.elapsedMilliseconds;
        scanCropMs += scanCropWatch.elapsedMilliseconds;
        yoloMs += yoloWatch.elapsedMilliseconds;
        recognizeMs += recognizeWatch.elapsedMilliseconds;
        if (detections.isNotEmpty) break;
      }
      frameTotalWatch.stop();

      if (!RealtimeAiConfig.enableTimingLogs) {
        debugPrint(
          'YOLO deteksi wajah: ${detections.length} frame=${frame.width}x${frame.height} sensorRot=${frame.rotationDegrees} usedRot=$selectedRotation rgb=${rgbImage.width}x${rgbImage.height}',
        );
      }
      if (RealtimeAiConfig.enableTimingLogs) {
        timingLines.add(
          '[AI frame $id] frameDecode=${frameDecodeWatch.elapsedMilliseconds}ms, '
          'yuvToRgb=${yuvToRgbWatch.elapsedMilliseconds}ms, '
          'rotate=${rotateMs}ms, '
          'scanCrop=${scanCropMs}ms, '
          'bboxYoloTotal=${yoloMs}ms, '
          'recognizeEmbeddingMatch=${recognizeMs}ms, '
          'totalFrame=${frameTotalWatch.elapsedMilliseconds}ms, '
          'boxes=$yoloBoxCount',
        );
      }

      mainPort.send({
        'type': 'result',
        'id': id,
        'faces': detections.map((face) => face.toMap()).toList(),
        'timingLog': timingLines.join('\n'),
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

Future<List<AiRecognizedFaceBox>> _recognizeDetections({
  required List<YoloDetectedFace> detections,
  required FaceEmbedder embedder,
  required List<AiKnownFace> knownFaces,
  required RealtimeSimilarityService similarity,
}) async {
  final recognized = <AiRecognizedFaceBox>[];

  for (final detection in detections) {
    final box = detection.box;
    if (math.min(box.width, box.height) <
        RealtimeAiConfig.minRecognizableFaceSize) {
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

    final match = similarity.findBestMatch(
      await embedder.embedImage(detection.croppedFace),
      knownFaces,
    );
    final isRecognized = match != null &&
        match.score >= RealtimeAiConfig.recognitionThreshold;

    if (match != null) {
      if (!RealtimeAiConfig.enableTimingLogs) {
        debugPrint(
          'Face match terbaik: ${match.name} skor=${match.score.toStringAsFixed(3)} threshold=${RealtimeAiConfig.recognitionThreshold}',
        );
      }
    }

    recognized.add(
      AiRecognizedFaceBox(
        left: box.left,
        top: box.top,
        width: box.width,
        height: box.height,
        name: isRecognized ? match!.name : 'Tidak dikenali',
        confidence: match?.score ?? 0,
        isRecognized: isRecognized,
        siswaId: isRecognized ? match!.siswaId : null,
      ),
    );
  }

  return recognized;
}

class _ScanRegion {
  const _ScanRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  static _ScanRegion? fromMessage(dynamic value) {
    if (value is! Map) return null;
    return _ScanRegion(
      left: (value['left'] as num).toDouble(),
      top: (value['top'] as num).toDouble(),
      width: (value['width'] as num).toDouble(),
      height: (value['height'] as num).toDouble(),
    );
  }
}

class _ScanFrame {
  const _ScanFrame({
    required this.image,
    required this.left,
    required this.top,
  });

  final img.Image image;
  final int left;
  final int top;
}

_ScanFrame _cropToScanRegion(img.Image image, _ScanRegion? region) {
  if (region == null) {
    return _ScanFrame(image: image, left: 0, top: 0);
  }

  final left = region.left.round().clamp(0, image.width - 1).toInt();
  final top = region.top.round().clamp(0, image.height - 1).toInt();
  final right = (region.left + region.width)
      .round()
      .clamp(left + 1, image.width)
      .toInt();
  final bottom = (region.top + region.height)
      .round()
      .clamp(top + 1, image.height)
      .toInt();
  final width = math.max(1, right - left);
  final height = math.max(1, bottom - top);

  return _ScanFrame(
    image: img.copyCrop(
      image,
      x: left,
      y: top,
      width: width,
      height: height,
    ),
    left: left,
    top: top,
  );
}

List<YoloDetectedFace> _offsetDetections(
  List<YoloDetectedFace> detections,
  int offsetX,
  int offsetY,
) {
  if (offsetX == 0 && offsetY == 0) return detections;

  return detections.map((detection) {
    final box = detection.box;
    final shiftedBox = YoloFaceBox(
      left: box.left + offsetX,
      top: box.top + offsetY,
      width: box.width,
      height: box.height,
      confidence: box.confidence,
      faceImage: box.faceImage,
    );

    return YoloDetectedFace(
      x: detection.x + offsetX,
      y: detection.y + offsetY,
      width: detection.width,
      height: detection.height,
      confidence: detection.confidence,
      croppedFace: detection.croppedFace,
      box: shiftedBox,
    );
  }).toList();
}
