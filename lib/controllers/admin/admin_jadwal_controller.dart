import '../../models/admin/jadwal_model.dart';
import '../../services/admin/jadwal_service.dart';

class AdminJadwalController {
  AdminJadwalController({JadwalService? service})
      : _service = service ?? JadwalService();

  final JadwalService _service;

  Future<List<JadwalModel>> loadJadwal() => _service.getAll();
}
