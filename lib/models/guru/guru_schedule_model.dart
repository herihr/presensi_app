part of '../../pages/guru/guru_page.dart';
class _GuruSchedule {
  const _GuruSchedule({
    required this.id,
    required this.kelasId,
    required this.subject,
    required this.room,
    required this.timeRange,
    required this.className,
    required this.day,
    required this.icon,
    required this.status,
  });

  final int id;
  final int kelasId;
  final String subject;
  final String room;
  final String timeRange;
  final String className;
  final String day;
  final IconData icon;
  final _ScheduleStatus status;

  factory _GuruSchedule.fromJson(
    Map<String, dynamic> json, {
    required Map<int, String> kelasById,
    required Map<int, String> mapelById,
  }) {
    final id = _intFromJson(json['id']) ?? 0;
    final kelasId = _intFromJson(json['kelas_id']) ?? 0;
    final mapelId = _intFromJson(json['mapel_id']) ?? 0;
    final jamMulai = json['jam_mulai']?.toString() ?? '';
    final jamSelesai = json['jam_selesai']?.toString() ?? '';
    return _GuruSchedule(
      id: id,
      kelasId: kelasId,
      subject: mapelById[mapelId] ?? 'Mata Pelajaran',
      room: json['ruang']?.toString() ?? 'Ruang kelas',
      timeRange: '$jamMulai - $jamSelesai',
      className: kelasById[kelasId] ?? 'Kelas',
      day: json['hari']?.toString() ?? '',
      icon: Icons.menu_book_rounded,
      status: _scheduleStatus(jamMulai, jamSelesai),
    );
  }
}

enum _ScheduleStatus { ongoing, upcoming }

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String _firstName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Guru';
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.first;
}

String _teacherGreeting(String? jenisKelamin) {
  final normalized = jenisKelamin?.trim().toLowerCase();
  if (normalized == 'perempuan') return 'Ibu';
  return 'Pak';
}

ImageProvider? _profileImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('data:image/')) {
    final commaIndex = path.indexOf(',');
    if (commaIndex == -1) return null;
    return MemoryImage(base64Decode(path.substring(commaIndex + 1)));
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('/uploads/')) {
    return NetworkImage(ApiService.resolveMediaUrl(path));
  }
  if (!File(path).existsSync()) return null;
  return FileImage(File(path));
}

String _indonesianDayName(DateTime date) {
  const days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  return days[date.weekday - 1];
}

bool _sameDayName(String left, String right) {
  return left.trim().toLowerCase() == right.trim().toLowerCase();
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _dateLabel(DateTime date) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MEI',
    'JUN',
    'JUL',
    'AGU',
    'SEP',
    'OKT',
    'NOV',
    'DES',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty);
  final letters = parts.take(2).map((item) => item[0].toUpperCase()).join();
  return letters.isEmpty ? 'S' : letters;
}

Color _avatarColor(int seed) {
  const colors = [
    Color(0xFFDCEBFF),
    Color(0xFFE6E8FF),
    Color(0xFFFFF3C4),
    Color(0xFFFFE1E7),
    Color(0xFFD1FAE5),
  ];
  return colors[seed.abs() % colors.length];
}

Color _initialColor(int seed) {
  const colors = [
    Color(0xFF2563EB),
    Color(0xFF4F46E5),
    Color(0xFFD97706),
    Color(0xFFE11D48),
    Color(0xFF059669),
  ];
  return colors[seed.abs() % colors.length];
}

_ScheduleStatus _scheduleStatus(String jamMulai, String jamSelesai) {
  final start = _parseClock(jamMulai);
  final end = _parseClock(jamSelesai);
  if (start == null || end == null) return _ScheduleStatus.upcoming;

  final now = DateTime.now();
  final startToday = DateTime(now.year, now.month, now.day, start.$1, start.$2);
  final endToday = DateTime(now.year, now.month, now.day, end.$1, end.$2);
  if (now.isAfter(startToday) && now.isBefore(endToday)) {
    return _ScheduleStatus.ongoing;
  }
  return _ScheduleStatus.upcoming;
}

(int, int)? _parseClock(String value) {
  final parts = value.trim().replaceAll('.', ':').split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return (hour, minute);
}

