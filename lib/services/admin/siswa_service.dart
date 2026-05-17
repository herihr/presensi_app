import '../../models/admin/siswa_model.dart';
import '../api_service.dart';

class SiswaService {
  final ApiService _api = ApiService();

  Future<List<SiswaModel>> getAll() async {
    final response = await _api.get('/api/siswa/');
    return (response as List)
        .map((item) => SiswaModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
