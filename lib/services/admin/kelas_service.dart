import '../../models/admin/kelas_model.dart';
import '../api_service.dart';

class KelasService {
  final ApiService _api = ApiService();

  Future<List<KelasModel>> getAll() async {
    final response = await _api.get('/api/kelas/');
    return (response as List)
        .map((item) => KelasModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
