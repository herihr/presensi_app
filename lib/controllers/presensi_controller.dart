import '../ai/realtime/realtime_similarity_service.dart';
import '../ai/shared/face_embedder.dart';
import '../ai/static_face/face_detector.dart';
import '../services/presensi_service.dart';

class PresensiController {
  final FaceDetector _detector = FaceDetector();
  final FaceEmbedder _embedder = FaceEmbedder();
  final SimilarityService _similarity = SimilarityService();
  final PresensiService _service = PresensiService();

  Future<void> presensi(
    dynamic image, {
    required int jadwalId,
    required int guruId,
  }) async {
    final face = await _detector.cropFace(image);
    final embedding = await _embedder.embed(face);

    final dbEmbeddings = await _service.getEmbeddings();
    final siswaId = _similarity.findClosest(embedding, dbEmbeddings);

    if (siswaId != null) {
      final now = DateTime.now();
      await _service.kirimPresensi(
        siswaId: siswaId,
        jadwalId: jadwalId,
        guruId: guruId,
        status: 'hadir',
        tanggal: _formatDate(now),
        jamPresensi: _formatTime(now),
      );
    }
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
