import '../../models/admin/kelas_model.dart';
import '../../services/admin/kelas_service.dart';

class AdminKelasController {
  AdminKelasController({KelasService? service})
      : _service = service ?? KelasService();

  final KelasService _service;

  Future<List<KelasModel>> loadKelas() => _service.getAll();
}
