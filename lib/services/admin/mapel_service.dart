import '../../models/admin/mapel_model.dart';
import '../api_service.dart';

class MapelService {
  final ApiService _api = ApiService();

  Future<List<MapelModel>> getAll() async {
    final response = await _api.get('/api/mata-pelajaran/');
    return (response as List)
        .map((item) => MapelModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
