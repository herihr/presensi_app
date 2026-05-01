import 'dart:math';

class SimilarityService {

  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0;
    double normA = 0;
    double normB = 0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += pow(a[i], 2);
      normB += pow(b[i], 2);
    }

    return dot / (sqrt(normA) * sqrt(normB));
  }

  int? findClosest(List<double> input, List embeddings) {
    double maxSim = -1;
    int? userId;

    for (var e in embeddings) {
      List<double> dbVector = List<double>.from(e['embedding']);

      double sim = cosineSimilarity(input, dbVector);

      if (sim > maxSim) {
        maxSim = sim;
        userId = e['user_id'];
      }
    }

    return userId;
  }
}