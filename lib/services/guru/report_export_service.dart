part of '../../pages/guru/guru_page.dart';

bool _isLastDayOfMonth(DateTime date) {
  final tomorrow = date.add(const Duration(days: 1));
  return tomorrow.month != date.month;
}

String _periodFileKey(_ReportPeriod period) {
  switch (period) {
    case _ReportPeriod.daily:
      return 'harian';
    case _ReportPeriod.weekly:
      return 'mingguan';
    case _ReportPeriod.monthly:
      return 'bulanan';
  }
}

String _periodTitle(_ReportPeriod period) {
  switch (period) {
    case _ReportPeriod.daily:
      return 'Harian';
    case _ReportPeriod.weekly:
      return 'Mingguan';
    case _ReportPeriod.monthly:
      return 'Bulanan';
  }
}

String _safeFileName(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  return normalized.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

int _rowPresentSlots(_RecapRow row) {
  return row.logs.where((item) => item).length;
}

int _rowAttendancePercent(_RecapRow row) {
  if (row.logs.isEmpty) return 0;
  return ((_rowPresentSlots(row) / row.logs.length) * 100).round();
}

String _excelStyles() {
  return '''
body {
  font-family: Arial, Helvetica, sans-serif;
  color: #111827;
}
table.report {
  border-collapse: collapse;
  width: 100%;
}
td, th {
  border: 1px solid #E5E7EB;
  padding: 9px 12px;
  vertical-align: middle;
}
.brand {
  background: #2563EB;
  color: #FFFFFF;
  font-size: 22px;
  font-weight: 700;
}
.subtitle {
  background: #DBEAFE;
  color: #1E3A8A;
  font-weight: 700;
}
.meta-label {
  background: #F8FAFC;
  color: #64748B;
  font-weight: 700;
  width: 160px;
}
.meta-value {
  color: #111827;
  font-weight: 700;
}
.card-label {
  background: #F8FAFC;
  color: #64748B;
  font-size: 11px;
  font-weight: 700;
}
.card-blue {
  background: #EFF6FF;
  color: #2563EB;
  font-size: 22px;
  font-weight: 700;
}
.card-green {
  background: #ECFDF5;
  color: #047857;
  font-size: 22px;
  font-weight: 700;
}
.card-red {
  background: #FEF2F2;
  color: #B91C1C;
  font-size: 22px;
  font-weight: 700;
}
.card-brown {
  background: #FFF7ED;
  color: #9A3412;
  font-size: 22px;
  font-weight: 700;
}
.section {
  background: #F1F5F9;
  color: #0F172A;
  font-size: 16px;
  font-weight: 700;
}
.table-head {
  background: #2563EB;
  color: #FFFFFF;
  font-weight: 700;
  text-align: center;
}
.center {
  text-align: center;
}
.name {
  font-weight: 700;
}
.hadir {
  background: #ECFDF5;
  color: #047857;
  font-weight: 700;
}
.alpa {
  background: #FEF2F2;
  color: #B91C1C;
  font-weight: 700;
}
.muted {
  color: #64748B;
}
.note {
  background: #F8FAFC;
  color: #64748B;
  font-size: 11px;
}
.spacer td {
  border: 0;
  height: 14px;
}
.page-break {
  page-break-before: always;
  mso-page-break-before: always;
}
''';
}

String _buildReportExcel({
  required _RecapData data,
  required _ReportPeriod period,
  required DateTime generatedAt,
}) {
  final tableColumnCount = 4 + data.columns.length;
  final layoutColumnCount = tableColumnCount < 6 ? 6 : tableColumnCount;
  final totalStudents = data.students.length;
  final presentPercent =
      totalStudents == 0 ? 0 : ((data.presentCount / totalStudents) * 100).round();
  final buffer = StringBuffer()
    ..writeln('<html>')
    ..writeln('<head>')
    ..writeln('<meta charset="UTF-8">')
    ..writeln('<style>')
    ..writeln(_excelStyles())
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<table class="report">')
    ..writeln(
      '<tr><td class="brand" colspan="$layoutColumnCount">PresenSatu - Laporan Presensi ${_htmlEscape(_periodTitle(period))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="subtitle" colspan="$layoutColumnCount">Kelas ${_htmlEscape(data.className)} | ${_htmlEscape(data.dayName)}, ${_htmlEscape(_dateLabel(data.date))} | Dibuat ${_htmlEscape(_dateLabel(generatedAt))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Kelas</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(data.className)}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Tanggal rekap</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(_dateLabel(data.date))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Tanggal dibuat</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(_dateLabel(generatedAt))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Total JP</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${data.columns.length}</td></tr>',
    )
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="card-label" colspan="2">TOTAL SISWA</td><td class="card-label" colspan="2">HADIR</td><td class="card-label" colspan="2">ALPA</td></tr>',
    )
    ..writeln(
      '<tr><td class="card-blue" colspan="2">$totalStudents siswa</td><td class="card-green" colspan="2">${data.presentCount} siswa</td><td class="card-red" colspan="2">${data.absentCount} siswa</td></tr>',
    )
    ..writeln(
      '<tr><td class="section" colspan="$layoutColumnCount">Ringkasan: Persentase hadir $presentPercent% dari $totalStudents siswa</td></tr>',
    )
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln('<tr><td class="section" colspan="$layoutColumnCount">Log Kehadiran Siswa</td></tr>')
    ..write(
      '<tr><th class="table-head">No</th><th class="table-head">Nama Siswa</th><th class="table-head">Status</th>',
    );

  for (final column in data.columns) {
    buffer.write(
      '<th class="table-head">J${column.number}<br>${_htmlEscape(column.mapelName)}</th>',
    );
  }
  buffer.writeln('<th class="table-head">Persentase</th></tr>');

  for (var index = 0; index < data.rows.length; index++) {
    final row = data.rows[index];
    final present = row.logs.any((item) => item);
    buffer
      ..write('<tr>')
      ..write('<td class="center">${index + 1}</td>')
      ..write('<td class="name">${_htmlEscape(row.name)}</td>')
      ..write(
        '<td class="center ${present ? 'hadir' : 'alpa'}">${present ? 'Hadir' : 'Alpa'}</td>',
      );
    for (final log in row.logs) {
      buffer.write(
        '<td class="center ${log ? 'hadir' : 'alpa'}">${log ? 'Hadir' : 'Tidak Hadir'}</td>',
      );
    }
    buffer.write('<td class="center name">${_rowAttendancePercent(row)}%</td>');
    buffer.writeln('</tr>');
  }

  buffer
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="note" colspan="$layoutColumnCount">Keterangan: Hadir dihitung per siswa jika minimal memiliki satu JP hadir. Persentase baris dihitung dari JP hadir dibagi total JP pada hari tersebut.</td></tr>',
    )
    ..writeln('</table>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

Future<_WeeklyReportData> _loadWeeklyReportData({
  required _RecapData baseData,
  required DateTime generatedAt,
}) async {
  if (baseData.classId == 0) {
    throw Exception('Kelas wali belum ditemukan untuk membuat laporan mingguan.');
  }

  final api = ApiService();
  final endDate = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
  final startDate = endDate.subtract(const Duration(days: 6));
  final dates = List<DateTime>.generate(
    7,
    (index) => startDate.add(Duration(days: index)),
  );

  final responses = await Future.wait<dynamic>([
    api.get('/api/siswa/kelas/${baseData.classId}'),
    api.get('/api/jadwal/kelas/${baseData.classId}'),
    api.get('/api/mata-pelajaran/'),
    ...dates.map((date) => api.get('/api/presensi/tanggal/${_dateKey(date)}')),
  ]);

  final students = (responses[0] as List)
      .map((item) => _RecapStudent.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final mapelById = <int, String>{};
  for (final raw in responses[2] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final id = _intFromJson(item['id']);
    if (id != null) mapelById[id] = item['nama_mapel']?.toString() ?? 'Mapel';
  }

  final allSchedules = (responses[1] as List)
      .map((item) => _RecapSchedule.fromJson(
            Map<String, dynamic>.from(item as Map),
            mapelById: mapelById,
          ))
      .where((item) => item.id != 0)
      .toList();

  final presentSlotsByStudent = <int, int>{
    for (final student in students) student.id: 0,
  };
  final totalSlotsByStudent = <int, int>{
    for (final student in students) student.id: 0,
  };
  final dayReports = <_WeeklyDayReport>[];

  for (var dateIndex = 0; dateIndex < dates.length; dateIndex++) {
    final date = dates[dateIndex];
    final dayName = _indonesianDayName(date);
    final presensiItems = (responses[3 + dateIndex] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final presentKeys = <String>{};
    final presentScheduleIds = <int>{};
    for (final item in presensiItems) {
      final status = item['status']?.toString().trim().toLowerCase();
      if (status != 'hadir') continue;
      final siswaId = _intFromJson(item['siswa_id']);
      final jadwalId = _intFromJson(item['jadwal_id']);
      if (siswaId != null && jadwalId != null) {
        presentKeys.add('$siswaId:$jadwalId');
        presentScheduleIds.add(jadwalId);
      }
    }

    final schedules = allSchedules
        .where(
          (item) =>
              _sameDayName(item.day, dayName) ||
              presentScheduleIds.contains(item.id),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

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

    final rows = students.map((student) {
      final logs = columns
          .map((column) => presentKeys.contains('${student.id}:${column.scheduleId}'))
          .toList();
      presentSlotsByStudent[student.id] =
          (presentSlotsByStudent[student.id] ?? 0) + logs.where((item) => item).length;
      totalSlotsByStudent[student.id] =
          (totalSlotsByStudent[student.id] ?? 0) + logs.length;
      return _RecapRow(
        initials: _initials(student.name),
        name: student.name,
        avatarColor: _avatarColor(student.id),
        initialColor: _initialColor(student.id),
        logs: logs,
      );
    }).toList();

    dayReports.add(
      _WeeklyDayReport(
        date: date,
        dayName: dayName,
        columns: columns,
        rows: rows,
      ),
    );
  }

  final summaries = students.map((student) {
    return _WeeklyStudentSummary(
      name: student.name,
      presentSlots: presentSlotsByStudent[student.id] ?? 0,
      totalSlots: totalSlotsByStudent[student.id] ?? 0,
    );
  }).toList();

  return _WeeklyReportData(
    className: baseData.className,
    startDate: startDate,
    endDate: endDate,
    generatedAt: generatedAt,
    students: students,
    dayReports: dayReports,
    summaries: summaries,
  );
}

String _buildWeeklyReportExcel({
  required _WeeklyReportData data,
}) {
  var layoutColumnCount = 6;
  for (final day in data.dayReports) {
    final count = 4 + day.columns.length;
    if (count > layoutColumnCount) layoutColumnCount = count;
  }

  final buffer = StringBuffer()
    ..writeln('<html>')
    ..writeln('<head>')
    ..writeln('<meta charset="UTF-8">')
    ..writeln('<style>')
    ..writeln(_excelStyles())
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<table class="report">')
    ..writeln(
      '<tr><td class="brand" colspan="$layoutColumnCount">PresenSatu - Laporan Presensi Mingguan</td></tr>',
    )
    ..writeln(
      '<tr><td class="subtitle" colspan="$layoutColumnCount">Kelas ${_htmlEscape(data.className)} | ${_htmlEscape(data.rangeLabel)} | Dibuat ${_htmlEscape(_dateLabel(data.generatedAt))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Kelas</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(data.className)}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Rentang laporan</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(data.rangeLabel)}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Tanggal dibuat</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(_dateLabel(data.generatedAt))}</td></tr>',
    )
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="card-label" colspan="2">TOTAL SISWA</td><td class="card-label" colspan="2">RATA-RATA HADIR</td><td class="card-label" colspan="2">TOTAL JP MINGGUAN</td></tr>',
    )
    ..writeln(
      '<tr><td class="card-blue" colspan="2">${data.students.length} siswa</td><td class="card-green" colspan="2">${data.averagePercent}%</td><td class="card-brown" colspan="2">${data.totalLessonSlots} JP</td></tr>',
    )
    ..writeln(
      '<tr><td class="section" colspan="$layoutColumnCount">Log Kehadiran 7 Hari Terakhir</td></tr>',
    );

  for (final day in data.dayReports) {
    final presentCount = day.columns.isEmpty
        ? 0
        : day.rows.where((row) => row.logs.any((item) => item)).length;
    final absentCount = day.columns.isEmpty
        ? 0
        : day.rows.where((row) => !row.logs.any((item) => item)).length;
    final dayPercent = data.students.isEmpty || day.columns.isEmpty
        ? 0
        : ((presentCount / data.students.length) * 100).round();
    buffer
      ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
      ..writeln(
        '<tr><td class="section" colspan="$layoutColumnCount">${_htmlEscape(day.dayName)}, ${_htmlEscape(_dateLabel(day.date))}</td></tr>',
      )
      ..writeln(
        '<tr><td class="meta-label">Ringkasan hari</td><td class="meta-value" colspan="${layoutColumnCount - 1}">Hadir $presentCount siswa | Alpa $absentCount siswa | Total JP ${day.columns.length} | Persentase hadir $dayPercent%</td></tr>',
      )
      ..write(
        '<tr><th class="table-head">No</th><th class="table-head">Nama Siswa</th><th class="table-head">Status</th>',
      );
    for (final column in day.columns) {
      buffer.write(
        '<th class="table-head">J${column.number}<br>${_htmlEscape(column.mapelName)}</th>',
      );
    }
    buffer.writeln('<th class="table-head">Persentase</th></tr>');

    for (var index = 0; index < day.rows.length; index++) {
      final row = day.rows[index];
      final present = row.logs.any((item) => item);
      final statusLabel = day.columns.isEmpty
          ? 'Tidak ada jadwal'
          : present
              ? 'Hadir'
              : 'Alpa';
      final statusClass = present
          ? 'hadir'
          : day.columns.isEmpty
              ? ''
              : 'alpa';
      buffer
        ..write('<tr>')
        ..write('<td class="center">${index + 1}</td>')
        ..write('<td class="name">${_htmlEscape(row.name)}</td>')
        ..write(
          '<td class="center $statusClass">${_htmlEscape(statusLabel)}</td>',
        );
      for (final log in row.logs) {
        buffer.write(
          '<td class="center ${log ? 'hadir' : 'alpa'}">${log ? 'Hadir' : 'Tidak Hadir'}</td>',
        );
      }
      buffer
        ..write('<td class="center name">${_rowAttendancePercent(row)}%</td>')
        ..writeln('</tr>');
    }
  }

  buffer
    ..writeln('<tr class="spacer page-break"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="brand" colspan="$layoutColumnCount">Rangkuman Kehadiran Mingguan</td></tr>',
    )
    ..writeln(
      '<tr><td class="subtitle" colspan="$layoutColumnCount">Persentase tiap siswa dihitung dari total JP hadir selama ${_htmlEscape(data.rangeLabel)}</td></tr>',
    )
    ..writeln(
      '<tr><th class="table-head">No</th><th class="table-head">Nama Siswa</th><th class="table-head">Hadir JP</th><th class="table-head">Total JP</th><th class="table-head">Persentase</th><th class="table-head">Keterangan</th></tr>',
    );
  for (var index = 0; index < data.summaries.length; index++) {
    final summary = data.summaries[index];
    final statusClass = summary.percent >= 75 ? 'hadir' : 'alpa';
    final note = summary.totalSlots == 0
        ? 'Tidak ada jadwal'
        : summary.percent >= 75
            ? 'Baik'
            : 'Perlu perhatian';
    buffer
      ..write('<tr>')
      ..write('<td class="center">${index + 1}</td>')
      ..write('<td class="name">${_htmlEscape(summary.name)}</td>')
      ..write('<td class="center hadir">${summary.presentSlots}</td>')
      ..write('<td class="center">${summary.totalSlots}</td>')
      ..write('<td class="center name">${summary.percent}%</td>')
      ..write('<td class="center $statusClass">${_htmlEscape(note)}</td>')
      ..writeln('</tr>');
  }

  buffer
    ..writeln(
      '<tr><td class="note" colspan="$layoutColumnCount">Keterangan: Hasil mingguan mengambil 7 hari terakhir sejak laporan dibuat. Status Baik dipakai jika persentase hadir minimal 75%.</td></tr>',
    )
    ..writeln('</table>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

String _buildReportPdf({
  required _RecapData data,
  required _ReportPeriod period,
  required DateTime generatedAt,
}) {
  final content = StringBuffer();

  void fillRect(
    double x,
    double y,
    double width,
    double height,
    String color,
  ) {
    content.writeln('q $color rg $x $y $width $height re f Q');
  }

  void strokeRect(
    double x,
    double y,
    double width,
    double height,
    String color, {
    double lineWidth = 1,
  }) {
    content.writeln('q $color RG $lineWidth w $x $y $width $height re S Q');
  }

  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    String color, {
    double lineWidth = 1,
  }) {
    content.writeln('q $color RG $lineWidth w $x1 $y1 m $x2 $y2 l S Q');
  }

  void text(
    String value,
    double x,
    double y, {
    int size = 10,
    String font = 'F1',
    String color = '0.090 0.110 0.160',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font $size Tf')
      ..writeln('$x $y Td')
      ..writeln('(${_pdfEscape(value)}) Tj')
      ..writeln('ET');
  }

  final title = 'Laporan Presensi ${_periodTitle(period)}';
  final totalStudents = data.students.length;
  final presentPercent =
      totalStudents == 0 ? 0 : ((data.presentCount / totalStudents) * 100).round();
  final periodLabel = _periodTitle(period);

  fillRect(0, 742, 595, 100, '0.145 0.388 0.922');
  text('PresenSatu', 42, 804, size: 18, font: 'F2', color: '1 1 1');
  text(title, 42, 778, size: 24, font: 'F2', color: '1 1 1');
  text(
    'Kelas ${data.className}  |  ${data.dayName}, ${_dateLabel(data.date)}  |  Dibuat ${_dateLabel(generatedAt)}',
    42,
    758,
    size: 10,
    color: '0.890 0.940 1',
  );

  fillRect(42, 674, 156, 46, '0.937 0.965 1');
  fillRect(219, 674, 156, 46, '0.925 0.988 0.961');
  fillRect(396, 674, 156, 46, '1 0.945 0.945');
  strokeRect(42, 674, 156, 46, '0.827 0.890 1');
  strokeRect(219, 674, 156, 46, '0.733 0.949 0.847');
  strokeRect(396, 674, 156, 46, '0.984 0.800 0.800');
  text('TOTAL SISWA', 56, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('$totalStudents', 56, 684, size: 19, font: 'F2', color: '0.145 0.388 0.922');
  text('HADIR', 233, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.presentCount} siswa', 233, 684, size: 19, font: 'F2', color: '0.047 0.545 0.310');
  text('ALPA', 410, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.absentCount} siswa', 410, 684, size: 19, font: 'F2', color: '0.796 0 0');

  fillRect(42, 626, 510, 30, '0.980 0.984 0.992');
  strokeRect(42, 626, 510, 30, '0.894 0.914 0.941');
  text('Ringkasan', 56, 638, size: 12, font: 'F2');
  text(
    'Persentase hadir $presentPercent%  |  Total JP ${data.columns.length}  |  Periode $periodLabel',
    150,
    638,
    size: 10,
    color: '0.392 0.455 0.545',
  );

  text('Log Kehadiran Siswa', 42, 590, size: 15, font: 'F2');
  fillRect(42, 556, 510, 26, '0.145 0.388 0.922');
  text('NO', 54, 565, size: 9, font: 'F2', color: '1 1 1');
  text('NAMA SISWA', 92, 565, size: 9, font: 'F2', color: '1 1 1');
  text('STATUS', 278, 565, size: 9, font: 'F2', color: '1 1 1');
  text('DETAIL JP', 356, 565, size: 9, font: 'F2', color: '1 1 1');
  text('PERSEN', 500, 565, size: 9, font: 'F2', color: '1 1 1');

  var y = 530.0;
  for (var index = 0; index < data.rows.length; index++) {
    if (y < 92) break;
    final row = data.rows[index];
    final present = row.logs.any((item) => item);
    final detail = row.logs.isEmpty
        ? '-'
        : row.logs
            .asMap()
            .entries
            .map((entry) => 'J${entry.key + 1}:${entry.value ? 'H' : 'A'}')
            .join('  ');
    final rowColor = index.isEven ? '1 1 1' : '0.980 0.984 0.992';
    fillRect(42, y - 8, 510, 28, rowColor);
    line(42, y - 8, 552, y - 8, '0.894 0.914 0.941');
    text('${index + 1}', 56, y, size: 10);
    text(row.name, 92, y, size: 10, font: 'F2');
    text(
      present ? 'Hadir' : 'Alpa',
      278,
      y,
      size: 10,
      font: 'F2',
      color: present ? '0.047 0.545 0.310' : '0.796 0 0',
    );
    text(detail, 356, y, size: 9, color: '0.392 0.455 0.545');
    text('${_rowAttendancePercent(row)}%', 508, y, size: 10, font: 'F2');
    y -= 28;
  }

  line(42, 76, 552, 76, '0.894 0.914 0.941');
  text('Keterangan: H = Hadir, A = Alpa/Tidak Hadir', 42, 58, size: 9, color: '0.392 0.455 0.545');
  text('Dokumen dibuat otomatis oleh PresenSatu', 360, 58, size: 9, color: '0.392 0.455 0.545');

  final stream = content.toString();
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 6 0 R >> >> /Contents 5 0 R >>\nendobj\n',
    '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '5 0 obj\n<< /Length ${stream.length} >>\nstream\n$stream\nendstream\nendobj\n',
    '6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
  ];

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var offset = buffer.length;
  for (final object in objects) {
    offsets.add(offset);
    buffer.write(object);
    offset += object.length;
  }

  final xrefOffset = offset;
  buffer
    ..writeln('xref')
    ..writeln('0 ${objects.length + 1}')
    ..writeln('0000000000 65535 f ');
  for (var index = 1; index < offsets.length; index++) {
    buffer.writeln('${offsets[index].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln('$xrefOffset')
    ..writeln('%%EOF');
  return buffer.toString();
}

String _buildWeeklyReportPdf({
  required _WeeklyReportData data,
}) {
  final pages = <String>[
    for (final day in data.dayReports) _buildWeeklyDayPdfPage(data, day),
    _buildWeeklySummaryPdfPage(data),
  ];
  return _buildPdfDocument(pages);
}

String _buildWeeklyDayPdfPage(_WeeklyReportData data, _WeeklyDayReport day) {
  final content = StringBuffer();

  void fillRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color rg $x $y $width $height re f Q');
  }

  void strokeRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color RG 1 w $x $y $width $height re S Q');
  }

  void line(double x1, double y1, double x2, double y2, String color) {
    content.writeln('q $color RG 1 w $x1 $y1 m $x2 $y2 l S Q');
  }

  void text(
    String value,
    double x,
    double y, {
    int size = 10,
    String font = 'F1',
    String color = '0.090 0.110 0.160',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font $size Tf')
      ..writeln('$x $y Td')
      ..writeln('(${_pdfEscape(value)}) Tj')
      ..writeln('ET');
  }

  final presentCount = day.columns.isEmpty
      ? 0
      : day.rows.where((row) => row.logs.any((item) => item)).length;
  final absentCount = day.columns.isEmpty
      ? 0
      : day.rows.where((row) => !row.logs.any((item) => item)).length;
  final percent = data.students.isEmpty || day.columns.isEmpty
      ? 0
      : ((presentCount / data.students.length) * 100).round();

  fillRect(0, 742, 595, 100, '0.145 0.388 0.922');
  text('PresenSatu', 42, 804, size: 18, font: 'F2', color: '1 1 1');
  text('Laporan Presensi Mingguan', 42, 778, size: 24, font: 'F2', color: '1 1 1');
  text(
    'Kelas ${data.className}  |  ${day.dayName}, ${_dateLabel(day.date)}  |  Rentang ${data.rangeLabel}',
    42,
    758,
    size: 10,
    color: '0.890 0.940 1',
  );

  fillRect(42, 674, 156, 46, '0.937 0.965 1');
  fillRect(219, 674, 156, 46, '0.925 0.988 0.961');
  fillRect(396, 674, 156, 46, '1 0.945 0.945');
  strokeRect(42, 674, 156, 46, '0.827 0.890 1');
  strokeRect(219, 674, 156, 46, '0.733 0.949 0.847');
  strokeRect(396, 674, 156, 46, '0.984 0.800 0.800');
  text('TOTAL SISWA', 56, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.students.length}', 56, 684, size: 19, font: 'F2', color: '0.145 0.388 0.922');
  text('HADIR', 233, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('$presentCount siswa', 233, 684, size: 19, font: 'F2', color: '0.047 0.545 0.310');
  text('ALPA', 410, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('$absentCount siswa', 410, 684, size: 19, font: 'F2', color: '0.796 0 0');

  fillRect(42, 626, 510, 30, '0.980 0.984 0.992');
  strokeRect(42, 626, 510, 30, '0.894 0.914 0.941');
  text('Ringkasan', 56, 638, size: 12, font: 'F2');
  text(
    'Persentase hadir $percent%  |  Total JP ${day.columns.length}  |  Dibuat ${_dateLabel(data.generatedAt)}',
    150,
    638,
    size: 10,
    color: '0.392 0.455 0.545',
  );

  text('Log Kehadiran Siswa', 42, 590, size: 15, font: 'F2');
  fillRect(42, 556, 510, 26, '0.145 0.388 0.922');
  text('NO', 54, 565, size: 9, font: 'F2', color: '1 1 1');
  text('NAMA SISWA', 92, 565, size: 9, font: 'F2', color: '1 1 1');
  text('STATUS', 278, 565, size: 9, font: 'F2', color: '1 1 1');
  text('DETAIL JP', 356, 565, size: 9, font: 'F2', color: '1 1 1');
  text('PERSEN', 500, 565, size: 9, font: 'F2', color: '1 1 1');

  var y = 530.0;
  for (var index = 0; index < day.rows.length; index++) {
    if (y < 92) break;
    final row = day.rows[index];
    final present = row.logs.any((item) => item);
    final statusLabel = day.columns.isEmpty
        ? 'Tidak ada jadwal'
        : present
            ? 'Hadir'
            : 'Alpa';
    final detail = row.logs.isEmpty
        ? '-'
        : row.logs
            .asMap()
            .entries
            .map((entry) => 'J${entry.key + 1}:${entry.value ? 'H' : 'A'}')
            .join('  ');
    fillRect(42, y - 8, 510, 28, index.isEven ? '1 1 1' : '0.980 0.984 0.992');
    line(42, y - 8, 552, y - 8, '0.894 0.914 0.941');
    text('${index + 1}', 56, y, size: 10);
    text(row.name, 92, y, size: 10, font: 'F2');
    text(
      statusLabel,
      278,
      y,
      size: 10,
      font: 'F2',
      color: present ? '0.047 0.545 0.310' : '0.796 0 0',
    );
    text(detail, 356, y, size: 9, color: '0.392 0.455 0.545');
    text('${_rowAttendancePercent(row)}%', 508, y, size: 10, font: 'F2');
    y -= 28;
  }

  if (day.columns.isEmpty) {
    text('Tidak ada jadwal pada hari ini.', 42, 520, size: 11, color: '0.392 0.455 0.545');
  }

  line(42, 76, 552, 76, '0.894 0.914 0.941');
  text('Keterangan: H = Hadir, A = Alpa/Tidak Hadir', 42, 58, size: 9, color: '0.392 0.455 0.545');
  text('Dokumen dibuat otomatis oleh PresenSatu', 360, 58, size: 9, color: '0.392 0.455 0.545');
  return content.toString();
}

String _buildWeeklySummaryPdfPage(_WeeklyReportData data) {
  final content = StringBuffer();

  void fillRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color rg $x $y $width $height re f Q');
  }

  void strokeRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color RG 1 w $x $y $width $height re S Q');
  }

  void line(double x1, double y1, double x2, double y2, String color) {
    content.writeln('q $color RG 1 w $x1 $y1 m $x2 $y2 l S Q');
  }

  void text(
    String value,
    double x,
    double y, {
    int size = 10,
    String font = 'F1',
    String color = '0.090 0.110 0.160',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font $size Tf')
      ..writeln('$x $y Td')
      ..writeln('(${_pdfEscape(value)}) Tj')
      ..writeln('ET');
  }

  fillRect(0, 742, 595, 100, '0.145 0.388 0.922');
  text('PresenSatu', 42, 804, size: 18, font: 'F2', color: '1 1 1');
  text('Rangkuman Kehadiran Mingguan', 42, 778, size: 24, font: 'F2', color: '1 1 1');
  text(
    'Kelas ${data.className}  |  ${data.rangeLabel}  |  Dibuat ${_dateLabel(data.generatedAt)}',
    42,
    758,
    size: 10,
    color: '0.890 0.940 1',
  );

  fillRect(42, 674, 156, 46, '0.937 0.965 1');
  fillRect(219, 674, 156, 46, '0.925 0.988 0.961');
  fillRect(396, 674, 156, 46, '1 0.945 0.945');
  strokeRect(42, 674, 156, 46, '0.827 0.890 1');
  strokeRect(219, 674, 156, 46, '0.733 0.949 0.847');
  strokeRect(396, 674, 156, 46, '0.984 0.800 0.800');
  text('TOTAL SISWA', 56, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.students.length}', 56, 684, size: 19, font: 'F2', color: '0.145 0.388 0.922');
  text('RATA-RATA', 233, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.averagePercent}%', 233, 684, size: 19, font: 'F2', color: '0.047 0.545 0.310');
  text('TOTAL JP', 410, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.totalLessonSlots}', 410, 684, size: 19, font: 'F2', color: '0.569 0.220 0');

  text('Persentase Kehadiran Tiap Siswa', 42, 638, size: 15, font: 'F2');
  fillRect(42, 604, 510, 26, '0.145 0.388 0.922');
  text('NO', 54, 613, size: 9, font: 'F2', color: '1 1 1');
  text('NAMA SISWA', 92, 613, size: 9, font: 'F2', color: '1 1 1');
  text('HADIR JP', 330, 613, size: 9, font: 'F2', color: '1 1 1');
  text('TOTAL JP', 410, 613, size: 9, font: 'F2', color: '1 1 1');
  text('PERSEN', 500, 613, size: 9, font: 'F2', color: '1 1 1');

  var y = 578.0;
  for (var index = 0; index < data.summaries.length; index++) {
    if (y < 92) break;
    final row = data.summaries[index];
    fillRect(42, y - 8, 510, 28, index.isEven ? '1 1 1' : '0.980 0.984 0.992');
    line(42, y - 8, 552, y - 8, '0.894 0.914 0.941');
    text('${index + 1}', 56, y, size: 10);
    text(row.name, 92, y, size: 10, font: 'F2');
    text('${row.presentSlots}', 342, y, size: 10, color: '0.047 0.545 0.310');
    text('${row.totalSlots}', 424, y, size: 10);
    text('${row.percent}%', 508, y, size: 10, font: 'F2');
    y -= 28;
  }

  line(42, 76, 552, 76, '0.894 0.914 0.941');
  text('Rangkuman dihitung dari 7 hari terakhir sejak laporan dibuat.', 42, 58, size: 9, color: '0.392 0.455 0.545');
  text('Dokumen dibuat otomatis oleh PresenSatu', 360, 58, size: 9, color: '0.392 0.455 0.545');
  return content.toString();
}

String _buildPdfDocument(List<String> streams) {
  final pageCount = streams.length;
  final f1Object = 3 + (pageCount * 2);
  final f2Object = f1Object + 1;
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
  ];

  final kids = <String>[];
  for (var index = 0; index < pageCount; index++) {
    kids.add('${3 + (index * 2)} 0 R');
  }
  objects.add(
    '2 0 obj\n<< /Type /Pages /Kids [${kids.join(' ')}] /Count $pageCount >>\nendobj\n',
  );

  for (var index = 0; index < pageCount; index++) {
    final pageObject = 3 + (index * 2);
    final contentObject = pageObject + 1;
    final stream = streams[index];
    objects
      ..add(
        '$pageObject 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 $f1Object 0 R /F2 $f2Object 0 R >> >> /Contents $contentObject 0 R >>\nendobj\n',
      )
      ..add(
        '$contentObject 0 obj\n<< /Length ${stream.length} >>\nstream\n$stream\nendstream\nendobj\n',
      );
  }

  objects
    ..add('$f1Object 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n')
    ..add('$f2Object 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var offset = buffer.length;
  for (final object in objects) {
    offsets.add(offset);
    buffer.write(object);
    offset += object.length;
  }

  final xrefOffset = offset;
  buffer
    ..writeln('xref')
    ..writeln('0 ${objects.length + 1}')
    ..writeln('0000000000 65535 f ');
  for (var index = 1; index < offsets.length; index++) {
    buffer.writeln('${offsets[index].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln('$xrefOffset')
    ..writeln('%%EOF');
  return buffer.toString();
}

String _pdfEscape(String value) {
  final asciiValue = value.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  return asciiValue
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

Future<String> _writeReportFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('presensi_app/downloads');
      final result = await channel.invokeMethod<String>('saveReport', {
        'fileName': fileName,
        'content': content,
        'mimeType': mimeType,
      });
      if (result != null && result.isNotEmpty) return result;
    } catch (_) {
      // Fallback ke penulisan file langsung untuk emulator/perangkat lama.
    }
  }

  final candidates = <Directory>[
    Directory('/storage/emulated/0/Download'),
    Directory('/storage/emulated/0/Downloads'),
    Directory.systemTemp,
  ];

  Object? lastError;
  for (final directory in candidates) {
    try {
      if (!directory.existsSync()) continue;
      final file = File('${directory.path}/$fileName');
      final encoding = mimeType == 'application/pdf' ? latin1 : utf8;
      final savedFile =
          await file.writeAsString(content, encoding: encoding, flush: true);
      return savedFile.path;
    } catch (error) {
      lastError = error;
    }
  }

  throw Exception(lastError ?? 'Folder download tidak ditemukan');
}

