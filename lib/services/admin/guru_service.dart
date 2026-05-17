import '../../models/admin/guru_model.dart';
import '../api_service.dart';

class GuruService {
  final ApiService _api = ApiService();

  Future<List<GuruModel>> getAll() async {
    final response = await _api.get('/api/guru/');
    return (response as List)
        .map((item) => GuruModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
