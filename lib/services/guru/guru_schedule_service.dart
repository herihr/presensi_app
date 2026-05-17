part of '../../pages/guru/guru_page.dart';

Future<List<_GuruSchedule>> _loadGuruSchedules(User user) async {
  final api = ApiService();
  try {
    final responses = await Future.wait([
      api.get('/api/jadwal/guru/${user.id}'),
      api.get('/api/kelas/'),
      api.get('/api/mata-pelajaran/'),
    ]);

    final kelasById = <int, String>{};
    for (final raw in responses[1] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = _intFromJson(item['id']);
      if (id != null) {
        kelasById[id] = item['nama_kelas']?.toString() ?? 'Kelas';
      }
    }

    final mapelById = <int, String>{};
    for (final raw in responses[2] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final id = _intFromJson(item['id']);
      if (id != null) {
        mapelById[id] = item['nama_mapel']?.toString() ?? 'Mata Pelajaran';
      }
    }

    final schedules = (responses[0] as List)
        .map(
          (item) => _GuruSchedule.fromJson(
            Map<String, dynamic>.from(item as Map),
            kelasById: kelasById,
            mapelById: mapelById,
          ),
        )
        .where((item) => item.id != 0 && item.kelasId != 0)
        .toList()
      ..sort((a, b) => a.timeRange.compareTo(b.timeRange));

    final todayName = _indonesianDayName(DateTime.now());
    return schedules
        .where((item) => _sameDayName(item.day, todayName))
        .toList();
  } catch (_) {
    return const [];
  }
}
