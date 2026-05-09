import 'api_service.dart';

class PresensiService {
  final ApiService _api = ApiService();

  Future<void> kirimPresensi({
    required int siswaId,
    required int jadwalId,
    required int guruId,
    required String status,
    required String tanggal,
    required String jamPresensi,
  }) async {
    await _api.post("/api/presensi/", {
      "siswa_id": siswaId,
      "jadwal_id": jadwalId,
      "guru_id": guruId,
      "status": status,
      "tanggal": tanggal,
      "jam_presensi": jamPresensi,
    });
  }

  Future<List<dynamic>> getEmbeddings() async {
    return await _api.get("/api/embedding/");
  }
}
