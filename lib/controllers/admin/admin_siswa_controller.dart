import '../../models/admin/siswa_model.dart';
import '../../services/admin/siswa_service.dart';

class AdminSiswaController {
  AdminSiswaController({SiswaService? service}) : _service = service ?? SiswaService();

  final SiswaService _service;

  Future<List<SiswaModel>> loadSiswa() => _service.getAll();
}
