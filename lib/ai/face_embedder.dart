class FaceEmbedder {
  Future<List<double>> embed(dynamic face) async {
    // TODO: integrasi FaceNet TFLite
    return List.generate(128, (i) => 0.1); // dummy vector
  }
}