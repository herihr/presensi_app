import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../ai/similarity_service.dart';
import '../../ai/realtime_face_detector.dart';
import '../../ai/face_embedder.dart';
import '../../services/api_service.dart';

class RealtimePresensiPage extends StatefulWidget {
  const RealtimePresensiPage({
    super.key,
    required this.mapel,
    required this.className,
    required this.jadwalId,
    required this.guruId,
  });

  final String mapel;
  final String className;
  final int jadwalId;
  final int guruId;

  @override
  State<RealtimePresensiPage> createState() => _RealtimePresensiPageState();
}

class _RealtimePresensiPageState extends State<RealtimePresensiPage> {
  final _detector = RealtimeFaceDetector();
  final _embedder = FaceEmbedder();
  final _similarity = SimilarityService();
  final _api = ApiService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _isInitializing = true;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  String _status = 'Menyiapkan kamera dan model deteksi...';
  int _frameCount = 0;
  List<_KnownFace> _knownFaces = const [];
  List<_RecognizedFaceBox> _recognizedFaces = const [];
  Size? _lastFrameSize;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _stopCamera();
    _detector.close();
    _embedder.close();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final modelInfo = await _detector.load();
      final knownFaces = await _loadKnownFaces();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Kamera tidak ditemukan di perangkat ini');
      }

      final preferredIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      _cameras = cameras;
      _cameraIndex = preferredIndex == -1 ? 0 : preferredIndex;
      _knownFaces = knownFaces;

      await _startCamera(
        cameras[_cameraIndex],
        readyStatus:
            'Presensi realtime aktif. $modelInfo. ${knownFaces.length} embedding siswa dimuat.',
      );
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _status = error.toString().replaceFirst('Exception: ', '');
      });
    }
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
            'Kamera ${_activeCameraLabel().toLowerCase()} aktif. Model deteksi wajah siap.',
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

  Future<List<_KnownFace>> _loadKnownFaces() async {
    try {
      final jadwal = await _api.get('/api/jadwal/${widget.jadwalId}');
      final kelasId = _intFromJson(jadwal['kelas_id']);
      final siswaResponse = kelasId == null
          ? await _api.get('/api/siswa/')
          : await _api.get('/api/siswa/kelas/$kelasId');
      final siswaById = <int, String>{};
      for (final item in siswaResponse as List) {
        final siswa = item as Map<String, dynamic>;
        final id = _intFromJson(siswa['id']);
        if (id != null) {
          siswaById[id] = siswa['nama']?.toString() ?? 'Siswa $id';
        }
      }

      final embeddingResponse = await _api.get('/api/embedding/');
      final knownFaces = <_KnownFace>[];
      for (final item in embeddingResponse as List) {
        final embeddingJson = item as Map<String, dynamic>;
        final siswaId = _intFromJson(embeddingJson['siswa_id']);
        final name = siswaId == null ? null : siswaById[siswaId];
        final embedding = _embeddingFromJson(embeddingJson['embedding']);
        if (siswaId != null && name != null && embedding.isNotEmpty) {
          knownFaces.add(
            _KnownFace(
              siswaId: siswaId,
              name: name,
              embedding: embedding,
            ),
          );
        }
      }
      return knownFaces;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    _frameCount++;
    if (_frameCount % 30 != 0 || !mounted || _isProcessingFrame) return;

    _isProcessingFrame = true;
    try {
      final detections = await _detector.detect(image);
      final recognized = <_RecognizedFaceBox>[];
      for (final box in detections) {
        final crop = box.faceImage;
        _FaceMatch? match;
        if (crop != null) {
          try {
            match = _bestKnownFace(await _embedder.embedImage(crop));
          } catch (_) {
            match = null;
          }
        }
        recognized.add(
          _RecognizedFaceBox(
            left: box.left,
            top: box.top,
            width: box.width,
            height: box.height,
            name: match?.face.name ?? 'Wajah tidak dikenal',
            confidence: match?.score ?? box.confidence,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _lastFrameSize = Size(image.width.toDouble(), image.height.toDouble());
        _recognizedFaces = recognized;
        _status = recognized.isEmpty
            ? 'Mencari wajah pada frame kamera...'
            : 'Wajah terdeteksi: ${recognized.map((item) => item.name).join(', ')}';
      });
    } finally {
      _isProcessingFrame = false;
    }
  }

  _FaceMatch? _bestKnownFace(List<double> probe) {
    if (_knownFaces.isEmpty) return null;

    _KnownFace? best;
    var bestScore = -1.0;
    for (final face in _knownFaces) {
      final score = _similarity.cosineSimilarity(probe, face.embedding);
      if (score > bestScore) {
        bestScore = score;
        best = face;
      }
    }
    if (best == null || bestScore < 0.65) return null;
    return _FaceMatch(face: best, score: bestScore);
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
                          widget.mapel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          widget.className,
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

  final List<_RecognizedFaceBox> faces;
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
      final facePaint = Paint()
        ..color = const Color(0xFF10B981)
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
      final labelPaint = Paint()..color = const Color(0xFF10B981);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(10)),
        labelPaint,
      );
      textPainter.paint(canvas, labelRect.topLeft + const Offset(9, 5));
    }
  }

  Rect _scaleFaceRect(_RecognizedFaceBox face, Size canvasSize) {
    final frame = frameSize;
    if (frame == null || frame.width == 0 || frame.height == 0) {
      return Rect.fromLTWH(
        canvasSize.width * 0.22,
        canvasSize.height * 0.28,
        canvasSize.width * 0.56,
        canvasSize.width * 0.56,
      );
    }

    final scaleX = canvasSize.width / frame.width;
    final scaleY = canvasSize.height / frame.height;
    return Rect.fromLTWH(
      face.left * scaleX,
      face.top * scaleY,
      face.width * scaleX,
      face.height * scaleY,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.frameSize != frameSize;
  }
}

class _KnownFace {
  const _KnownFace({
    required this.siswaId,
    required this.name,
    required this.embedding,
  });

  final int siswaId;
  final String name;
  final List<double> embedding;
}

class _FaceMatch {
  const _FaceMatch({
    required this.face,
    required this.score,
  });

  final _KnownFace face;
  final double score;
}

class _RecognizedFaceBox {
  const _RecognizedFaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.name,
    required this.confidence,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String name;
  final double confidence;
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
