part of '../../pages/guru/guru_page.dart';

class _RecapData {
  const _RecapData({
    required this.date,
    required this.dayName,
    required this.classId,
    required this.className,
    required this.students,
    required this.columns,
    required this.rows,
    required this.message,
  });

  final DateTime date;
  final String dayName;
  final int classId;
  final String className;
  final List<_RecapStudent> students;
  final List<_RecapColumn> columns;
  final List<_RecapRow> rows;
  final String? message;

  int get presentCount {
    if (columns.isEmpty) return 0;
    return rows.where((row) => row.logs.any((item) => item)).length;
  }

  int get absentCount {
    if (columns.isEmpty) return 0;
    return rows.where((row) => !row.logs.any((item) => item)).length;
  }

  factory _RecapData.empty({
    required DateTime date,
    required String dayName,
    required String message,
  }) {
    return _RecapData(
      date: date,
      dayName: dayName,
      classId: 0,
      className: '-',
      students: const [],
      columns: const [],
      rows: const [],
      message: message,
    );
  }
}

class _RecapStudent {
  const _RecapStudent({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory _RecapStudent.fromJson(Map<String, dynamic> json) {
    return _RecapStudent(
      id: _intFromJson(json['id']) ?? 0,
      name: json['nama']?.toString() ?? 'Siswa',
    );
  }
}

class _RecapSchedule {
  const _RecapSchedule({
    required this.id,
    required this.mapelName,
    required this.day,
    required this.start,
    required this.end,
  });

  final int id;
  final String mapelName;
  final String day;
  final String start;
  final String end;

  int get lessonHours {
    final startClock = _parseClock(start);
    final endClock = _parseClock(end);
    if (startClock == null || endClock == null) return 1;

    final startDate = DateTime(2026, 1, 1, startClock.$1, startClock.$2);
    final endDate = DateTime(2026, 1, 1, endClock.$1, endClock.$2);
    final minutes = endDate.difference(startDate).inMinutes;
    if (minutes <= 0) return 1;
    return (minutes / 40).round().clamp(1, 8).toInt();
  }

  factory _RecapSchedule.fromJson(
    Map<String, dynamic> json, {
    required Map<int, String> mapelById,
  }) {
    final mapelId = _intFromJson(json['mapel_id']) ?? 0;
    return _RecapSchedule(
      id: _intFromJson(json['id']) ?? 0,
      mapelName: mapelById[mapelId] ?? 'Mata Pelajaran',
      day: json['hari']?.toString() ?? '',
      start: json['jam_mulai']?.toString() ?? '',
      end: json['jam_selesai']?.toString() ?? '',
    );
  }
}

class _RecapColumn {
  const _RecapColumn({
    required this.number,
    required this.scheduleId,
    required this.mapelName,
  });

  final int number;
  final int scheduleId;
  final String mapelName;
}

class _RecapRow {
  const _RecapRow({
    required this.initials,
    required this.name,
    required this.avatarColor,
    required this.initialColor,
    required this.logs,
  });

  final String initials;
  final String name;
  final Color avatarColor;
  final Color initialColor;
  final List<bool> logs;
}

class _WeeklyReportData {
  const _WeeklyReportData({
    required this.className,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.students,
    required this.dayReports,
    required this.summaries,
  });

  final String className;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final List<_RecapStudent> students;
  final List<_WeeklyDayReport> dayReports;
  final List<_WeeklyStudentSummary> summaries;

  String get rangeLabel => '${_dateLabel(startDate)} - ${_dateLabel(endDate)}';

  int get totalLessonSlots => dayReports.fold<int>(
        0,
        (total, item) => total + item.columns.length,
      );

  int get averagePercent {
    if (summaries.isEmpty) return 0;
    final totalPercent = summaries.fold<int>(
      0,
      (total, item) => total + item.percent,
    );
    return (totalPercent / summaries.length).round();
  }
}

class _WeeklyDayReport {
  const _WeeklyDayReport({
    required this.date,
    required this.dayName,
    required this.columns,
    required this.rows,
  });

  final DateTime date;
  final String dayName;
  final List<_RecapColumn> columns;
  final List<_RecapRow> rows;
}

class _WeeklyStudentSummary {
  const _WeeklyStudentSummary({
    required this.name,
    required this.presentSlots,
    required this.totalSlots,
  });

  final String name;
  final int presentSlots;
  final int totalSlots;

  int get percent {
    if (totalSlots == 0) return 0;
    return ((presentSlots / totalSlots) * 100).round();
  }
}

