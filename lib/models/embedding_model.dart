class Embedding {
  final int siswaId;
  final List<double> vector;

  Embedding({
    required this.siswaId,
    required this.vector,
  });

  factory Embedding.fromJson(Map<String, dynamic> json) {
    return Embedding(
      siswaId: json['siswa_id'],
      vector: List<double>.from(json['embedding']),
    );
  }
}
