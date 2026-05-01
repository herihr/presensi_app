import '../ai/face_detector.dart';
import '../ai/face_embedder.dart';
import '../ai/similarity_service.dart';
import '../services/presensi_service.dart';

class PresensiController {
  final FaceDetector _detector = FaceDetector();
  final FaceEmbedder _embedder = FaceEmbedder();
  final SimilarityService _similarity = SimilarityService();
  final PresensiService _service = PresensiService();

  Future<void> presensi(dynamic image) async {
    final face = await _detector.detect(image);
    final embedding = await _embedder.embed(face);

    final dbEmbeddings = await _service.getEmbeddings();
    final userId = _similarity.findClosest(embedding, dbEmbeddings);

    if (userId != null) {
      await _service.kirimPresensi(userId);
    }
  }
}