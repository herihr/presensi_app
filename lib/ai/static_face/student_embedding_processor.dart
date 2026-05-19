import 'package:image/image.dart' as img;

import '../shared/face_embedder.dart';
import 'face_detector.dart';

class StudentEmbeddingProcessor {
  StudentEmbeddingProcessor({
    FaceDetector? detector,
    FaceEmbedder? embedder,
  })  : _detector = detector ?? FaceDetector(),
        _embedder = embedder ?? FaceEmbedder();

  final FaceDetector _detector;
  final FaceEmbedder _embedder;

  Future<List<double>> createEmbedding(dynamic image) async {
    final face = await _detector.cropFace(image);
    return _embedder.embedImage(face);
  }

  Future<List<List<double>>> createEmbeddings(Iterable<dynamic> images) async {
    final results = <List<double>>[];
    for (final image in images) {
      results.add(await createEmbedding(image));
    }
    return results;
  }

  Future<img.Image> cropFace(dynamic image) => _detector.cropFace(image);

  void close() {
    _detector.close();
    _embedder.close();
  }
}
