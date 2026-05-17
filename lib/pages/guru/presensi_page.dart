import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';
import 'realtime_presensi_page.dart';

const presensiPageResultRekap = 'rekap';

class PresensiPage extends StatefulWidget {
  const PresensiPage({
    super.key,
    required this.mapel,
    required this.className,
    required this.jadwalId,
    required this.kelasId,
    required this.guruId,
  });

  final String mapel;
  final String className;
  final int jadwalId;
  final int kelasId;
  final int guruId;

  @override
  State<PresensiPage> createState() => _PresensiPageState();
}

class _PresensiPageState extends State<PresensiPage> {
  final _api = ApiService();
  final _searchController = TextEditingController();

  late Future<List<_StudentAttendance>> _studentsFuture;
  List<_StudentAttendance> _students = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _studentsFuture = _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_StudentAttendance>> _loadStudents() async {
    try {
      final todayKey = _dateKey(DateTime.now());
      final responses = await Future.wait([
        _api.get('/api/siswa/kelas/${widget.kelasId}'),
        _api.get('/api/presensi/tanggal/$todayKey'),
      ]);

      final presentStudentIds = <int>{};
      for (final raw in responses[1] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final jadwalId = _intFromJson(item['jadwal_id']);
        final siswaId = _intFromJson(item['siswa_id']);
        final status = item['status']?.toString().toLowerCase();
        if (jadwalId == widget.jadwalId && siswaId != null && status == 'hadir') {
          presentStudentIds.add(siswaId);
        }
      }

      final students = (responses[0] as List)
          .map(
            (item) => _StudentAttendance.fromJson(
              Map<String, dynamic>.from(item as Map),
              presentStudentIds: presentStudentIds,
            ),
          )
          .toList();

      _students = students;
      return students;
    } catch (error) {
      debugPrint('Data presensi siswa gagal dimuat: $error');
      _students = const [];
      return const [];
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _studentsFuture = _loadStudents();
    });
    await _studentsFuture;
  }

  Future<void> _downloadPresensiExcel() async {
    try {
      final students = _students.isEmpty ? await _studentsFuture : _students;
      final today = DateTime.now();
      final fileName =
          'presensi_${_safeFileName(widget.className)}_${_safeFileName(widget.mapel)}_${_dateKey(today)}.xls';
      final content = _buildExcelContent(
        students: students,
        date: today,
        mapel: widget.mapel,
        className: widget.className,
      );
      final savedPath = await _writeDownloadFile(fileName, content);

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Data presensi berhasil disimpan:\n$savedPath',
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal',
        message: 'Data presensi belum bisa diunduh. $error',
      );
    }
  }

  Future<void> _scanStudent(_StudentAttendance student) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealtimePresensiPage(
          mapel: widget.mapel,
          className: widget.className,
          jadwalId: widget.jadwalId,
          kelasId: widget.kelasId,
          guruId: widget.guruId,
          targetStudentId: student.id,
          targetStudentName: student.name,
          onRecognizedStudents: (ids) {
            if (ids.contains(student.id)) {
              _markRecognizedStudentsPresent({student.id});
            }
          },
        ),
      ),
    );
  }

  Future<void> _startRealtimePresence() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealtimePresensiPage(
          mapel: widget.mapel,
          className: widget.className,
          jadwalId: widget.jadwalId,
          kelasId: widget.kelasId,
          guruId: widget.guruId,
          onRecognizedStudents: _markRecognizedStudentsPresent,
        ),
      ),
    );
  }

  void _markRecognizedStudentsPresent(Set<int> siswaIds) {
    if (siswaIds.isEmpty || !mounted) return;

    setState(() {
      _students = _students
          .map(
            (student) => siswaIds.contains(student.id)
                ? student.copyWith(status: _AttendanceStatus.hadir)
                : student,
          )
          .toList();
    });
    _saveRecognizedPresensi(siswaIds);
  }

  Future<void> _saveRecognizedPresensi(Set<int> siswaIds) async {
    final now = DateTime.now();
    final tanggal = _dateKey(now);
    final jamPresensi =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final siswaId in siswaIds) {
      try {
        await _api.post('/api/presensi/', {
          'siswa_id': siswaId,
          'jadwal_id': widget.jadwalId,
          'guru_id': widget.guruId,
          'status': 'hadir',
          'tanggal': tanggal,
          'jam_presensi': jamPresensi,
        });
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (!message.contains('sudah ada')) {
          debugPrint('Presensi siswa $siswaId gagal disimpan: $error');
        }
      }
    }
  }

  List<_StudentAttendance> _filteredStudents(List<_StudentAttendance> source) {
    final data = _students.isEmpty ? source : _students;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return data;
    return data.where((student) {
      return student.name.toLowerCase().contains(query) ||
          student.nis.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<_StudentAttendance>>(
            future: _studentsFuture,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final source = snapshot.data ?? _students;
              final students = _filteredStudents(source);

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PresensiTopBar(
                      mapel: widget.mapel,
                      className: widget.className,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Cari siswa...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF6B7280),
                          size: 28,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFC3C6D7)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFFC3C6D7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Row(
                      children: [
                        Text(
                          'Siswa',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: const Color(0xFF191B23),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '(${students.length} total)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF737686),
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE1E5F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: _startRealtimePresence,
                                icon: const Icon(
                                  Icons.center_focus_strong_rounded,
                                  size: 20,
                                ),
                                label: const Text('Presensi Semua'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _downloadPresensiExcel,
                                icon: const Icon(Icons.download_rounded, size: 20),
                                label: const Text('Excel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(
                                    color: Color(0xFFD9E4FF),
                                    width: 1.4,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (students.isEmpty)
                      const _EmptyStudentsCard()
                    else
                      ...students.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StudentCard(
                            student: student,
                            onScan: () => _scanStudent(student),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x100B3558),
                blurRadius: 20,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PresensiNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Beranda',
                isSelected: false,
                onTap: () => Navigator.of(context).pop(),
              ),
              _PresensiNavItem(
                icon: Icons.insert_chart_outlined_rounded,
                label: 'Rekap',
                isSelected: false,
                onTap: () => Navigator.of(context).pop(presensiPageResultRekap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresensiTopBar extends StatelessWidget {
  const _PresensiTopBar({
    required this.mapel,
    required this.className,
  });

  final String mapel;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF64748B),
          tooltip: 'Kembali',
        ),
        const SizedBox(width: 4),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mapel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                className,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
          color: const Color(0xFF64748B),
          iconSize: 30,
        ),
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.onScan,
  });

  final _StudentAttendance student;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final imageProvider = _photoProvider(student.fotoUrl);
    final isPresent = student.status == _AttendanceStatus.hadir;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0B3558),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE5E7EB),
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Text(
                        student.name.isEmpty
                            ? 'S'
                            : student.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isPresent
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusBadge(status: student.status),
                    Text(
                      'NIS: ${student.nis}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF737686),
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton(
              onPressed: onScan,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.center_focus_strong_rounded, size: 25),
              tooltip: 'Pindai wajah siswa',
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider? _photoProvider(String? path) {
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
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final isPresent = status == _AttendanceStatus.hadir;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isPresent ? const Color(0xFFD6F9E6) : const Color(0xFFFFDCE0),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        isPresent ? 'HADIR' : 'ALPA',
        style: TextStyle(
          color: isPresent ? const Color(0xFF078B4F) : const Color(0xFFCC0000),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PresensiNavItem extends StatelessWidget {
  const _PresensiNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color:
                    isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                size: 26,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStudentsCard extends StatelessWidget {
  const _EmptyStudentsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'Belum ada siswa pada kelas ini.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF737686)),
      ),
    );
  }
}

class _StudentAttendance {
  const _StudentAttendance({
    required this.id,
    required this.name,
    required this.nis,
    required this.status,
    this.fotoUrl,
  });

  final int id;
  final String name;
  final String nis;
  final _AttendanceStatus status;
  final String? fotoUrl;

  factory _StudentAttendance.fromJson(
    Map<String, dynamic> json, {
    required Set<int> presentStudentIds,
  }) {
    final id = _intFromJson(json['id']) ?? 0;
    return _StudentAttendance(
      id: id,
      name: json['nama']?.toString() ?? '',
      nis: json['nis']?.toString() ?? '-',
      fotoUrl: json['foto_url']?.toString(),
      status: presentStudentIds.contains(id)
          ? _AttendanceStatus.hadir
          : _AttendanceStatus.alpa,
    );
  }

  _StudentAttendance copyWith({
    String? name,
    String? nis,
    _AttendanceStatus? status,
    String? fotoUrl,
  }) {
    return _StudentAttendance(
      id: id,
      name: name ?? this.name,
      nis: nis ?? this.nis,
      status: status ?? this.status,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}

enum _AttendanceStatus { hadir, alpa }

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _dateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _safeFileName(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  return normalized.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
}

String _excelEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

String _buildExcelContent({
  required List<_StudentAttendance> students,
  required DateTime date,
  required String mapel,
  required String className,
}) {
  final buffer = StringBuffer()
    ..writeln('<html>')
    ..writeln('<head>')
    ..writeln('<meta charset="UTF-8">')
    ..writeln('<style>')
    ..writeln('table { border-collapse: collapse; font-family: Arial; }')
    ..writeln('th, td { padding: 8px 12px; }')
    ..writeln('.hadir { color: #078B4F; font-weight: bold; }')
    ..writeln('.alpa { color: #CC0000; font-weight: bold; }')
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<table border="1">')
    ..writeln(
      '<tr><th colspan="5">Data Presensi ${_excelEscape(_dateLabel(date))}</th></tr>',
    )
    ..writeln(
      '<tr><td>Mata Pelajaran</td><td colspan="4">${_excelEscape(mapel)}</td></tr>',
    )
    ..writeln(
      '<tr><td>Kelas</td><td colspan="4">${_excelEscape(className)}</td></tr>',
    )
    ..writeln(
      '<tr><td>Tanggal</td><td colspan="4">${_excelEscape(_dateLabel(date))}</td></tr>',
    )
    ..writeln(
      '<tr><th>No</th><th>Nama Siswa</th><th>NIS</th><th>Status</th><th>Keterangan</th></tr>',
    );

  for (var index = 0; index < students.length; index++) {
    final student = students[index];
    final isPresent = student.status == _AttendanceStatus.hadir;
    buffer.writeln(
      '<tr>'
      '<td>${index + 1}</td>'
      '<td>${_excelEscape(student.name)}</td>'
      '<td>${_excelEscape(student.nis)}</td>'
      '<td class="${isPresent ? 'hadir' : 'alpa'}">${isPresent ? 'Hadir' : 'Alpa'}</td>'
      '<td>${isPresent ? 'Sudah presensi' : 'Belum presensi'}</td>'
      '</tr>',
    );
  }

  buffer
    ..writeln('</table>')
    ..writeln('</body>')
    ..writeln('</html>');

  return buffer.toString();
}

Future<String> _writeDownloadFile(String fileName, String content) async {
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('presensi_app/downloads');
      final result = await channel.invokeMethod<String>('saveExcel', {
        'fileName': fileName,
        'content': content,
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
      final savedFile = await file.writeAsString(content, encoding: utf8, flush: true);
      return savedFile.path;
    } catch (error) {
      lastError = error;
    }
  }

  throw Exception(lastError ?? 'Folder download tidak ditemukan');
}
