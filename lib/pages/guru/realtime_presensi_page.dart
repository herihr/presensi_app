import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../ai/realtime_face_detector.dart';
import '../../services/api_service.dart';

class RealtimePresensiPage extends StatefulWidget {
  const RealtimePresensiPage({
    super.key,
    required this.mapel,
    required this.className,
    required this.jadwalId,
    required this.kelasId,
    required this.guruId,
    this.onRecognizedStudents,
    this.targetStudentId,
    this.targetStudentName,
  });

  final String mapel;
  final String className;
  final int jadwalId;
  final int kelasId;
  final int guruId;
  final ValueChanged<Set<int>>? onRecognizedStudents;
  final int? targetStudentId;
  final String? targetStudentName;

  @override
  State<RealtimePresensiPage> createState() => _RealtimePresensiPageState();
}

class _RealtimePresensiPageState extends State<RealtimePresensiPage> {
  final _aiProcessor = RealtimeAiProcessor();
  final _api = ApiService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _isInitializing = true;
  bool _isStreaming = false;
  String _status = 'Menyiapkan kamera dan model deteksi...';
  List<AiRecognizedFaceBox> _recognizedFaces = const [];
  final Set<int> _reportedStudentIds = {};
  Size? _lastFrameSize;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _stopCamera();
    _aiProcessor.stop();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Kamera tidak ditemukan di perangkat ini');
      }

      final preferredIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _cameras = cameras;
      _cameraIndex = preferredIndex == -1 ? 0 : preferredIndex;

      await _startCamera(
        cameras[_cameraIndex],
        readyStatus: 'Kamera aktif. Menyiapkan model AI dan embedding siswa...',
      );
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });

      await _initializeAiWorker();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _status = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _initializeAiWorker() async {
    try {
      final knownFaces = await _loadKnownFaces();
      await _aiProcessor.start(knownFaces: knownFaces);
      if (!mounted) return;
      final targetName = widget.targetStudentName;
      setState(() {
        _status = targetName == null
            ? 'Presensi realtime aktif. AI isolate siap. Maksimal 3 frame per detik diproses. ${knownFaces.length} embedding siswa dimuat.'
            : 'Pindai wajah $targetName. Arahkan wajah ke kamera sampai dikenali.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _friendlyAiError(error);
      });
    }
  }

  String _friendlyAiError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.toLowerCase().contains('timeoutexception')) {
      return 'Kamera aktif, tetapi model AI terlalu lama disiapkan. Tutup halaman ini lalu buka ulang scan.';
    }
    return 'Kamera aktif, tetapi AI belum siap: $message';
  }

  Future<void> _startCamera(
    CameraDescription camera, {
    required String readyStatus,
  }) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    debugPrint(
      'Kamera aktif: ${camera.lensDirection.name}, sensorOrientation=${camera.sensorOrientation}',
    );
    await controller.startImageStream(_onCameraFrame);

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
      _isStreaming = true;
      _lastFrameSize = null;
      _recognizedFaces = const [];
      _status = readyStatus;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isInitializing) return;

    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    setState(() {
      _isInitializing = true;
      _status = 'Mengganti kamera...';
      _recognizedFaces = const [];
    });

    try {
      await _stopCamera();
      _cameraIndex = nextIndex;
      await _startCamera(
        _cameras[_cameraIndex],
        readyStatus:
            'Kamera ${_activeCameraLabel().toLowerCase()} aktif. AI isolate tetap berjalan.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<List<AiKnownFace>> _loadKnownFaces() async {
    try {
      final siswaResponse = await _api.get('/api/siswa/kelas/${widget.kelasId}');
      final siswaById = <int, String>{};
      for (final item in siswaResponse as List) {
        final siswa = item as Map<String, dynamic>;
        final id = _intFromJson(siswa['id']);
        if (id != null) {
          siswaById[id] = siswa['nama']?.toString() ?? 'Siswa $id';
        }
      }

      final embeddingResponse = await _api.get('/api/embedding/');
      final knownFaces = <AiKnownFace>[];
      for (final item in embeddingResponse as List) {
        final embeddingJson = item as Map<String, dynamic>;
        final siswaId = _intFromJson(embeddingJson['siswa_id']);
        if (widget.targetStudentId != null &&
            siswaId != widget.targetStudentId) {
          continue;
        }
        final name = siswaId == null ? null : siswaById[siswaId];
        final embedding = _embeddingFromJson(embeddingJson['embedding']);
        if (siswaId != null && name != null && embedding.isNotEmpty) {
          knownFaces.add(
            AiKnownFace(
              siswaId: siswaId,
              name: name,
              embedding: embedding,
            ),
          );
        }
      }
      return knownFaces;
    } catch (error) {
      throw StateError(
        'Embedding siswa tidak bisa dimuat: ${error.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    if (!mounted) return;

    try {
      final rotationDegrees =
          _cameraController?.description.sensorOrientation ?? 0;
      final recognized = await _aiProcessor.processFrame(
        image,
        rotationDegrees: rotationDegrees,
      );
      if (recognized == null) return;

      if (!mounted) return;
      _reportRecognizedStudents(recognized);
      setState(() {
        _lastFrameSize = _processedFrameSize(image, rotationDegrees);
        _recognizedFaces = recognized;
        _status = recognized.isEmpty
            ? 'Mencari wajah pada frame kamera...'
            : 'Wajah terdeteksi: ${recognized.map((item) => item.name).join(', ')}';
        debugPrint(
          'UI update wajah: ${recognized.length}, frameSize=${_lastFrameSize!.width.toStringAsFixed(0)}x${_lastFrameSize!.height.toStringAsFixed(0)}',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _reportRecognizedStudents(List<AiRecognizedFaceBox> faces) {
    final ids = faces
        .where((face) => face.isRecognized && face.siswaId != null)
        .map((face) => face.siswaId!)
        .where(
          (id) => widget.targetStudentId == null || id == widget.targetStudentId,
        )
        .where((id) => !_reportedStudentIds.contains(id))
        .toSet();
    if (ids.isEmpty) return;

    _reportedStudentIds.addAll(ids);
    widget.onRecognizedStudents?.call(ids);
  }

  Size _processedFrameSize(CameraImage image, int rotationDegrees) {
    final normalizedRotation = rotationDegrees % 360;
    final isRotated = normalizedRotation == 90 || normalizedRotation == 270;
    final width = isRotated ? image.height.toDouble() : image.width.toDouble();
    final height = isRotated ? image.width.toDouble() : image.height.toDouble();
    const maxAiFrameSide = 480.0;
    final scale = math.min(1.0, maxAiFrameSide / math.max(width, height));
    return Size(width * scale, height * scale);
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    if (controller == null) return;

    try {
      if (_isStreaming) {
        await controller.stopImageStream();
      }
      await controller.dispose();
      _cameraController = null;
      _isStreaming = false;
    } catch (_) {
      // Kamera mungkin sudah dilepas oleh lifecycle plugin.
    }
  }

  String _activeCameraLabel() {
    if (_cameras.isEmpty) return 'Kamera';
    final direction = _cameras[_cameraIndex].lensDirection;
    if (direction == CameraLensDirection.front) return 'Kamera depan';
    if (direction == CameraLensDirection.back) return 'Kamera belakang';
    return 'Kamera eksternal';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final isReady = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: isReady
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.previewSize!.height,
                        height: controller.value.previewSize!.width,
                        child: CameraPreview(controller),
                      ),
                    )
                  : const ColoredBox(color: Colors.black),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(
                    faces: _recognizedFaces,
                    frameSize: _lastFrameSize,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Kembali',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.targetStudentName ?? widget.mapel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.targetStudentName == null
                              ? widget.className
                              : '${widget.mapel} • ${widget.className}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _cameras.length < 2 || _isInitializing
                        ? null
                        : _switchCamera,
                    icon: const Icon(Icons.cameraswitch_rounded),
                    tooltip: 'Ganti kamera',
                  ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isInitializing
                            ? Icons.hourglass_top_rounded
                            : Icons.center_focus_strong_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  const _ScannerOverlayPainter({
    required this.faces,
    required this.frameSize,
  });

  final List<AiRecognizedFaceBox> faces;
  final Size? frameSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * 0.72,
      height: size.width * 0.72,
    );
    final radius = Radius.circular(size.width * 0.08);

    final dimPaint = Paint()..color = Colors.black.withOpacity(0.26);
    final clearPath = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(clearPath, dimPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), borderPaint);

    for (final face in faces) {
      final faceRect = _scaleFaceRect(face, size);
      final accentColor =
          face.isRecognized ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      final facePaint = Paint()
        ..color = accentColor
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(faceRect, const Radius.circular(18)),
        facePaint,
      );

      final label = '${face.name} ${(face.confidence * 100).round()}%';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.7);

      final labelRect = Rect.fromLTWH(
        faceRect.left,
        (faceRect.top - textPainter.height - 12)
            .clamp(8, size.height)
            .toDouble(),
        textPainter.width + 18,
        textPainter.height + 10,
      );
      final labelPaint = Paint()..color = accentColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(10)),
        labelPaint,
      );
      textPainter.paint(canvas, labelRect.topLeft + const Offset(9, 5));
    }
  }

  Rect _scaleFaceRect(AiRecognizedFaceBox face, Size canvasSize) {
    final frame = frameSize;
    if (frame == null || frame.width == 0 || frame.height == 0) {
      return Rect.fromLTWH(
        canvasSize.width * 0.22,
        canvasSize.height * 0.28,
        canvasSize.width * 0.56,
        canvasSize.width * 0.56,
      );
    }

    final scale = math.max(
      canvasSize.width / frame.width,
      canvasSize.height / frame.height,
    );
    final drawnWidth = frame.width * scale;
    final drawnHeight = frame.height * scale;
    final offsetX = (canvasSize.width - drawnWidth) / 2;
    final offsetY = (canvasSize.height - drawnHeight) / 2;
    return Rect.fromLTWH(
      offsetX + face.left * scale,
      offsetY + face.top * scale,
      face.width * scale,
      face.height * scale,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.frameSize != frameSize;
  }
}

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

List<double> _embeddingFromJson(dynamic value) {
  if (value is List) {
    return value.map((item) => (item as num).toDouble()).toList();
  }
  return const [];
}
