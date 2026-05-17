import '../../models/admin/jadwal_model.dart';
import '../api_service.dart';

class JadwalService {
  final ApiService _api = ApiService();

  Future<List<JadwalModel>> getAll() async {
    final response = await _api.get('/api/jadwal/');
    return (response as List)
        .map((item) => JadwalModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
