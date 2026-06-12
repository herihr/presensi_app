import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../shared/ai_models.dart';
import '../shared/face_embedder.dart';
import 'realtime_ai_config.dart';
import 'realtime_ai_worker.dart';

class RealtimeAiProcessor {
  RealtimeAiProcessor({this.onTimingLog});

  static const int targetFps = RealtimeAiConfig.targetFps;
  static const double recognitionThreshold =
      RealtimeAiConfig.recognitionThreshold;
  static const double minRecognizableFaceSize =
      RealtimeAiConfig.minRecognizableFaceSize;
  static const int _minFrameIntervalMs = 1000 ~/ targetFps;

  Isolate? _isolate;
  SendPort? _workerPort;
  ReceivePort? _receivePort;
  final void Function(String log)? onTimingLog;
  final _pending = <int, Completer<List<AiRecognizedFaceBox>>>{};
  int _nextFrameId = 0;
  bool _isBusy = false;
  DateTime _lastAcceptedAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> start({required List<AiKnownFace> knownFaces}) async {
    if (_workerPort != null) return;

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
        readyCompleter.completeError(
          StateError('AI isolate gagal dimulai: $message'),
        );
      }
    });

    _isolate = await Isolate.spawn(
      realtimeAiWorkerEntry,
      {
        'sendPort': _receivePort!.sendPort,
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
    ui.Rect? scanRegion,
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
      'bytesPerPixel': image.planes
          .map((plane) => plane.bytesPerPixel ?? 1)
          .toList(),
      'scanRegion': scanRegion == null
          ? null
          : {
              'left': scanRegion.left,
              'top': scanRegion.top,
              'width': scanRegion.width,
              'height': scanRegion.height,
            },
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
    final timingLog = message['timingLog'];
    if (timingLog is String && timingLog.trim().isNotEmpty) {
      onTimingLog?.call(timingLog);
    }
    final faces = rawFaces is List
        ? rawFaces
              .map(
                (item) => AiRecognizedFaceBox.fromMap(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
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
