class Embedding {
  final int userId;
  final List<double> vector;

  Embedding({
    required this.userId,
    required this.vector,
  });

  factory Embedding.fromJson(Map<String, dynamic> json) {
    return Embedding(
      userId: json['user_id'],
      vector: List<double>.from(json['embedding']),
    );
  }
}