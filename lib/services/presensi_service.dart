import 'api_service.dart';

class PresensiService {
  final ApiService _api = ApiService();

  Future<void> kirimPresensi(int userId) async {
    await _api.post("/presensi", {
      "user_id": userId,
    });
  }

  Future<List<dynamic>> getEmbeddings() async {
    return await _api.get("/embedding");
  }
}