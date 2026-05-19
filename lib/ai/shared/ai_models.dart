class AiKnownFace {
  const AiKnownFace({
    required this.siswaId,
    required this.name,
    required this.embedding,
  });

  final int siswaId;
  final String name;
  final List<double> embedding;

  factory AiKnownFace.fromMap(Map<String, dynamic> map) {
    return AiKnownFace(
      siswaId: map['siswaId'] as int,
      name: map['name']?.toString() ?? 'Siswa',
      embedding: (map['embedding'] as List)
          .map((item) => (item as num).toDouble())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'siswaId': siswaId,
      'name': name,
      'embedding': embedding,
    };
  }
}

class AiRecognizedFaceBox {
  const AiRecognizedFaceBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.name,
    required this.confidence,
    required this.isRecognized,
    this.siswaId,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final String name;
  final double confidence;
  final bool isRecognized;
  final int? siswaId;

  factory AiRecognizedFaceBox.fromMap(Map<String, dynamic> map) {
    return AiRecognizedFaceBox(
      left: (map['left'] as num).toDouble(),
      top: (map['top'] as num).toDouble(),
      width: (map['width'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      name: map['name']?.toString() ?? 'Tidak dikenali',
      confidence: (map['confidence'] as num).toDouble(),
      isRecognized: map['isRecognized'] == true,
      siswaId: map['siswaId'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
      'name': name,
      'confidence': confidence,
      'isRecognized': isRecognized,
      'siswaId': siswaId,
    };
  }
}
