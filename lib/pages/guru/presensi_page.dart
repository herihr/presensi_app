import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';
import 'realtime_presensi_page.dart';

class PresensiPage extends StatefulWidget {
  const PresensiPage({
    super.key,
    required this.mapel,
    required this.className,
    required this.jadwalId,
    required this.guruId,
  });

  final String mapel;
  final String className;
  final int jadwalId;
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
      final jadwal = await _api.get('/api/jadwal/${widget.jadwalId}');
      final kelasId = _intFromJson(jadwal['kelas_id']);
      if (kelasId == null) return _fallbackStudents;

      final response = await _api.get('/api/siswa/kelas/$kelasId');
      final students = (response as List)
          .map((item) => _StudentAttendance.fromJson(item as Map<String, dynamic>))
          .toList();

      if (students.isEmpty) return _fallbackStudents;
      _students = students;
      return students;
    } catch (_) {
      _students = _fallbackStudents;
      return _fallbackStudents;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _studentsFuture = _loadStudents();
    });
    await _studentsFuture;
  }

  Future<void> _scanStudent(_StudentAttendance student) async {
    setState(() {
      _students = _students
          .map(
            (item) => item.id == student.id
                ? item.copyWith(status: _AttendanceStatus.hadir)
                : item,
          )
          .toList();
    });

    await AppAlert.warning(
      context,
      title: 'Pindai Wajah',
      message: 'Pindai wajah ${student.name} akan dibuka berikutnya.',
    );
  }

  void _startRealtimePresence() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RealtimePresensiPage(
          mapel: widget.mapel,
          className: widget.className,
          jadwalId: widget.jadwalId,
          guruId: widget.guruId,
        ),
      ),
    );
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
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list_rounded, size: 20),
                          label: const Text('Saring'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton.icon(
                        onPressed: _startRealtimePresence,
                        icon: const Icon(Icons.center_focus_strong_rounded),
                        label: const Text('Mulai Presensi Semua Siswa'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _PresensiNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Beranda',
                isSelected: false,
                onTap: () => Navigator.of(context).pop(),
              ),
              _PresensiNavItem(
                icon: Icons.center_focus_strong_rounded,
                label: 'Pindai',
                isSelected: false,
                onTap: _startRealtimePresence,
              ),
              _PresensiNavItem(
                icon: Icons.groups_rounded,
                label: 'Siswa',
                isSelected: true,
                onTap: () {},
              ),
              _PresensiNavItem(
                icon: Icons.insert_chart_outlined_rounded,
                label: 'Rekap',
                isSelected: false,
                onTap: () {},
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
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0B3558),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
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
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 12,
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
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            height: 58,
            child: IconButton(
              onPressed: onScan,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEFF6FF),
                foregroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.center_focus_strong_rounded, size: 31),
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

  factory _StudentAttendance.fromJson(Map<String, dynamic> json) {
    return _StudentAttendance(
      id: _intFromJson(json['id']) ?? 0,
      name: json['nama']?.toString() ?? '',
      nis: json['nis']?.toString() ?? '-',
      fotoUrl: json['foto_url']?.toString(),
      status: _AttendanceStatus.alpa,
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

const _fallbackStudents = [
  _StudentAttendance(
    id: 1,
    name: 'Adrian Maulana',
    nis: '2024001',
    status: _AttendanceStatus.hadir,
  ),
  _StudentAttendance(
    id: 2,
    name: 'Bella Safitri',
    nis: '2024002',
    status: _AttendanceStatus.alpa,
  ),
  _StudentAttendance(
    id: 3,
    name: 'Chandra Wijaya',
    nis: '2024003',
    status: _AttendanceStatus.hadir,
  ),
  _StudentAttendance(
    id: 4,
    name: 'Diana Putri',
    nis: '2024004',
    status: _AttendanceStatus.hadir,
  ),
  _StudentAttendance(
    id: 5,
    name: 'Eko Kurniawan',
    nis: '2024005',
    status: _AttendanceStatus.alpa,
  ),
];
