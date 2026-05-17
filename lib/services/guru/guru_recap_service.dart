part of '../../pages/guru/guru_page.dart';

Future<_RecapData> _loadRecapData(
  User user, {
  DateTime? date,
  bool fallbackAllSchedules = true,
}) async {
  final api = ApiService();
  final sourceDate = date ?? DateTime.now();
  final today = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
  final todayKey = _dateKey(today);
  final todayName = _indonesianDayName(today);

  final kelasResponse = await api.get('/api/kelas/');
  final kelasList = (kelasResponse as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  Map<String, dynamic>? waliKelas;
  for (final item in kelasList) {
    if (_intFromJson(item['wali_kelas_id']) == user.id) {
      waliKelas = item;
      break;
    }
  }

  if (waliKelas == null) {
    return _RecapData.empty(
      date: today,
      dayName: todayName,
      message: 'Guru ini belum menjadi wali kelas.',
    );
  }

  final kelasId = _intFromJson(waliKelas['id']) ?? 0;
  final kelasName = waliKelas['nama_kelas']?.toString() ?? 'Kelas';
  final responses = await Future.wait([
    api.get('/api/siswa/kelas/$kelasId'),
    api.get('/api/jadwal/kelas/$kelasId'),
    api.get('/api/presensi/tanggal/$todayKey'),
    api.get('/api/mata-pelajaran/'),
  ]);

  final siswa = (responses[0] as List)
      .map((item) => _RecapStudent.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final mapelById = <int, String>{};
  for (final raw in responses[3] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final id = _intFromJson(item['id']);
    if (id != null) mapelById[id] = item['nama_mapel']?.toString() ?? 'Mapel';
  }

  final presentKeys = <String>{};
  final presentScheduleIds = <int>{};
  for (final raw in responses[2] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final status = item['status']?.toString().trim().toLowerCase();
    if (status != 'hadir') continue;
    final siswaId = _intFromJson(item['siswa_id']);
    final jadwalId = _intFromJson(item['jadwal_id']);
    if (siswaId != null && jadwalId != null) {
      presentKeys.add('$siswaId:$jadwalId');
      presentScheduleIds.add(jadwalId);
    }
  }

  final allSchedules = (responses[1] as List)
      .map((item) => _RecapSchedule.fromJson(
            Map<String, dynamic>.from(item as Map),
            mapelById: mapelById,
          ))
      .where((item) => item.id != 0)
      .toList();

  final schedules = allSchedules
      .where(
        (item) =>
            _sameDayName(item.day, todayName) ||
            presentScheduleIds.contains(item.id),
      )
      .toList();

  if (schedules.isEmpty && fallbackAllSchedules) {
    schedules.addAll(allSchedules);
  }
  schedules.sort((a, b) => a.start.compareTo(b.start));

  final columns = <_RecapColumn>[];
  var jpNumber = 1;
  for (final schedule in schedules) {
    for (var index = 0; index < schedule.lessonHours; index++) {
      columns.add(
        _RecapColumn(
          number: jpNumber++,
          scheduleId: schedule.id,
          mapelName: schedule.mapelName,
        ),
      );
    }
  }

  final rows = siswa.map((student) {
    return _RecapRow(
      initials: _initials(student.name),
      name: student.name,
      avatarColor: _avatarColor(student.id),
      initialColor: _initialColor(student.id),
      logs: columns
          .map((column) => presentKeys.contains('${student.id}:${column.scheduleId}'))
          .toList(),
    );
  }).toList();

  return _RecapData(
    date: today,
    dayName: todayName,
    classId: kelasId,
    className: kelasName,
    students: siswa,
    columns: columns,
    rows: rows,
    message: null,
  );
}

