import '../../models/admin/guru_model.dart';
import '../../services/admin/guru_service.dart';

class AdminGuruController {
  AdminGuruController({GuruService? service}) : _service = service ?? GuruService();

  final GuruService _service;

  Future<List<GuruModel>> loadGuru() => _service.getAll();
}
