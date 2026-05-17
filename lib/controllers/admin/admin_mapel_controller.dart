import '../../models/admin/mapel_model.dart';
import '../../services/admin/mapel_service.dart';

class AdminMapelController {
  AdminMapelController({MapelService? service})
      : _service = service ?? MapelService();

  final MapelService _service;

  Future<List<MapelModel>> loadMapel() => _service.getAll();
}
