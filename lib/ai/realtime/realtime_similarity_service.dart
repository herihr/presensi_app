import 'dart:math';

import '../shared/ai_models.dart';

class RealtimeSimilarityService {
  const RealtimeSimilarityService();

  RealtimeFaceMatch? findBestMatch(
    List<double> probe,
    List<AiKnownFace> knownFaces,
  ) {
    RealtimeFaceMatch? best;
    var bestScore = -1.0;

    for (final face in knownFaces) {
      final score = cosineSimilarity(probe, face.embedding);
      if (score > bestScore) {
        bestScore = score;
        best = RealtimeFaceMatch(
          siswaId: face.siswaId,
          name: face.name,
          score: score,
        );
      }
    }

    return best;
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return -1;

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return -1;
    return dot / denominator;
  }
}

class RealtimeFaceMatch {
  const RealtimeFaceMatch({
    required this.siswaId,
    required this.name,
    required this.score,
  });

  final int siswaId;
  final String name;
  final double score;
}

class SimilarityService {
  final _realtime = const RealtimeSimilarityService();

  double cosineSimilarity(List<double> a, List<double> b) {
    return _realtime.cosineSimilarity(a, b);
  }

  int? findClosest(List<double> input, List embeddings) {
    var maxSim = -1.0;
    int? userId;

    for (final e in embeddings) {
      final dbVector = List<double>.from(e['embedding'] as List);
      final sim = cosineSimilarity(input, dbVector);

      if (sim > maxSim) {
        maxSim = sim;
        userId = e['siswa_id'] as int?;
      }
    }

    return userId;
  }
}
