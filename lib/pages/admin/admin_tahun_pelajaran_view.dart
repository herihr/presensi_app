import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class AdminTahunPelajaranView extends StatefulWidget {
  const AdminTahunPelajaranView({super.key});

  @override
  State<AdminTahunPelajaranView> createState() =>
      _AdminTahunPelajaranViewState();
}

class _AdminTahunPelajaranViewState extends State<AdminTahunPelajaranView> {
  final ApiService _api = ApiService();
  final TextEditingController _namaTahunController = TextEditingController();

  bool _loading = true;
  bool _savingYear = false;
  bool _savingPromotion = false;
  bool _loadingStudents = false;
  bool _newYearActive = false;

  List<_TahunPelajaranItem> _years = [];
  List<_KelasOption> _classes = [];
  List<_SiswaOption> _students = [];
  Set<int> _selectedStudentIds = {};

  int? _sourceYearId;
  int? _targetYearId;
  int? _sourceClassId;
  int? _targetClassId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _namaTahunController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        _api.get('/api/tahun-pelajaran/'),
        _api.get('/api/kelas/'),
      ]);

      final years =
          (responses[0] as List)
              .map((item) => _TahunPelajaranItem.fromJson(item as Map))
              .toList()
            ..sort((a, b) => b.nama.compareTo(a.nama));

      final classes =
          (responses[1] as List)
              .map((item) => _KelasOption.fromJson(item as Map))
              .toList()
            ..sort(_compareKelas);

      final activeYear = _firstOrNull(years.where((item) => item.isAktif));

      if (!mounted) return;
      setState(() {
        _years = years;
        _classes = classes;
        _sourceYearId ??= activeYear?.id ?? _firstOrNull(years)?.id;
        _targetYearId ??= activeYear?.id ?? _firstOrNull(years)?.id;
        _sourceClassId ??= _firstOrNull(classes)?.id;
        _targetClassId ??= _firstOrNull(classes)?.id;
        _loading = false;
      });
      await _loadStudents();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await AppAlert.error(
        context,
        title: 'Gagal Memuat Data',
        message: _cleanError(error),
      );
    }
  }

  Future<void> _loadStudents() async {
    final sourceClassId = _sourceClassId;
    final sourceYearId = _sourceYearId;
    if (sourceClassId == null || sourceYearId == null) {
      setState(() {
        _students = [];
        _selectedStudentIds = {};
      });
      return;
    }

    setState(() {
      _loadingStudents = true;
      _students = [];
      _selectedStudentIds = {};
    });

    try {
      final response = await _api.get(
        '/api/siswa/kelas/$sourceClassId?tahun_pelajaran_id=$sourceYearId',
      );
      final students =
          (response as List)
              .map((item) => _SiswaOption.fromJson(item as Map))
              .toList()
            ..sort((a, b) => a.nama.compareTo(b.nama));
      if (!mounted) return;
      setState(() {
        _students = students;
        _selectedStudentIds = students.map((item) => item.id).toSet();
        _loadingStudents = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingStudents = false);
      await AppAlert.error(
        context,
        title: 'Gagal Memuat Siswa',
        message: _cleanError(error),
      );
    }
  }

  Future<void> _createYear() async {
    final nama = _namaTahunController.text.trim();
    if (nama.isEmpty) {
      await AppAlert.warning(
        context,
        title: 'Data Belum Lengkap',
        message: 'Isi nama tahun pelajaran terlebih dahulu.',
      );
      return;
    }

    setState(() => _savingYear = true);
    try {
      final response = await _api.post('/api/tahun-pelajaran/', {
        'nama': nama,
        'is_aktif': _newYearActive,
      });
      final created = _TahunPelajaranItem.fromJson(response as Map);
      if (!mounted) return;
      _namaTahunController.clear();
      setState(() {
        _savingYear = false;
        _newYearActive = false;
        _targetYearId = created.id;
        if (created.isAktif) _sourceYearId = created.id;
      });
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tahun pelajaran ${created.nama} berhasil ditambahkan.',
      );
      await _loadInitialData();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingYear = false);
      await AppAlert.error(
        context,
        title: 'Gagal Menyimpan',
        message: _cleanError(error),
      );
    }
  }

  Future<void> _setActiveYear(_TahunPelajaranItem year) async {
    if (year.isAktif) return;

    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Aktifkan Tahun?',
      message:
          'Tahun pelajaran ${year.nama} akan menjadi tahun aktif untuk input baru.',
      confirmText: 'Aktifkan',
    );
    if (!confirmed) return;

    try {
      await _api.put('/api/tahun-pelajaran/${year.id}/aktif', {});
      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Tahun pelajaran ${year.nama} sekarang aktif.',
      );
      await _loadInitialData();
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal Mengaktifkan',
        message: _cleanError(error),
      );
    }
  }

  Future<void> _promoteStudents() async {
    if (_targetYearId == null ||
        _sourceYearId == null ||
        _sourceClassId == null ||
        _targetClassId == null) {
      await AppAlert.warning(
        context,
        title: 'Data Belum Lengkap',
        message:
            'Pilih tahun asal, kelas asal, tahun tujuan, dan kelas tujuan.',
      );
      return;
    }

    if (_selectedStudentIds.isEmpty) {
      await AppAlert.warning(
        context,
        title: 'Belum Ada Siswa',
        message: 'Pilih minimal satu siswa yang akan dinaikkan kelas.',
      );
      return;
    }

    final targetYear = _yearName(_targetYearId);
    final targetClass = _className(_targetClassId);
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Simpan Naik Kelas?',
      message:
          '${_selectedStudentIds.length} siswa akan dipindahkan ke $targetClass untuk tahun pelajaran $targetYear.',
      confirmText: 'Simpan',
    );
    if (!confirmed) return;

    setState(() => _savingPromotion = true);
    try {
      await _api.post('/api/siswa/naik-kelas', {
        'tahun_pelajaran_id': _targetYearId,
        'items': _selectedStudentIds
            .map(
              (id) => {
                'siswa_id': id,
                'kelas_id': _targetClassId,
                'status': 'aktif',
              },
            )
            .toList(),
      });
      if (!mounted) return;
      setState(() => _savingPromotion = false);
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Data kenaikan kelas berhasil disimpan.',
      );
      await _loadStudents();
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingPromotion = false);
      await AppAlert.error(
        context,
        title: 'Gagal Menyimpan',
        message: _cleanError(error),
      );
    }
  }

  void _toggleAllStudents(bool value) {
    setState(() {
      if (value) {
        _selectedStudentIds = _students.map((item) => item.id).toSet();
      } else {
        _selectedStudentIds.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tahun Pelajaran',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kelola tahun aktif dan perpindahan kelas siswa',
              style: TextStyle(
                color: Color(0xFF5F6372),
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            _buildYearListCard(),
            const SizedBox(height: 18),
            _buildCreateYearCard(),
            const SizedBox(height: 18),
            _buildPromotionCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildYearListCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.event_available_rounded,
            title: 'Daftar Tahun',
            subtitle: '${_years.length} tahun pelajaran tersimpan',
          ),
          const SizedBox(height: 16),
          if (_years.isEmpty)
            const _EmptyState(message: 'Belum ada tahun pelajaran.')
          else
            ..._years.map(_buildYearTile),
        ],
      ),
    );
  }

  Widget _buildYearTile(_TahunPelajaranItem year) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: year.isAktif ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: year.isAktif
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              year.isAktif
                  ? Icons.check_circle_rounded
                  : Icons.calendar_month_rounded,
              color: year.isAktif
                  ? const Color(0xFF10B981)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  year.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  year.isAktif ? 'Sedang aktif' : 'Tidak aktif',
                  style: TextStyle(
                    color: year.isAktif
                        ? const Color(0xFF059669)
                        : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!year.isAktif)
            IconButton.filledTonal(
              tooltip: 'Jadikan aktif',
              onPressed: () => _setActiveYear(year),
              icon: const Icon(Icons.done_rounded),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateYearCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.add_rounded,
            title: 'Tambah Tahun',
            subtitle: 'Contoh penulisan: 2026/2027',
          ),
          const SizedBox(height: 16),
          _TextInput(
            controller: _namaTahunController,
            label: 'Nama tahun pelajaran',
            hint: '2026/2027',
            icon: Icons.edit_calendar_rounded,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _newYearActive,
            activeThumbColor: const Color(0xFF2563EB),
            title: const Text(
              'Jadikan tahun aktif',
              style: TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: const Text(
              'Input siswa dan jadwal baru akan mengikuti tahun aktif.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            onChanged: (value) => setState(() => _newYearActive = value),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingYear ? null : _createYear,
              icon: _savingYear
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_savingYear ? 'Menyimpan' : 'Simpan Tahun'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionCard() {
    final allSelected =
        _students.isNotEmpty && _selectedStudentIds.length == _students.length;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.trending_up_rounded,
            title: 'Naik Kelas',
            subtitle: 'Pindahkan siswa ke kelas pada tahun pelajaran tujuan',
          ),
          const SizedBox(height: 16),
          _DropdownInput<int>(
            label: 'Tahun asal',
            value: _sourceYearId,
            items: _years
                .map(
                  (year) => DropdownMenuItem<int>(
                    value: year.id,
                    child: Text(year.label),
                  ),
                )
                .toList(),
            icon: Icons.history_rounded,
            onChanged: (value) async {
              setState(() => _sourceYearId = value);
              await _loadStudents();
            },
          ),
          const SizedBox(height: 12),
          _DropdownInput<int>(
            label: 'Kelas asal',
            value: _sourceClassId,
            items: _classes
                .map(
                  (kelas) => DropdownMenuItem<int>(
                    value: kelas.id,
                    child: Text(kelas.nama),
                  ),
                )
                .toList(),
            icon: Icons.meeting_room_rounded,
            onChanged: (value) async {
              setState(() => _sourceClassId = value);
              await _loadStudents();
            },
          ),
          const SizedBox(height: 12),
          _DropdownInput<int>(
            label: 'Tahun tujuan',
            value: _targetYearId,
            items: _years
                .map(
                  (year) => DropdownMenuItem<int>(
                    value: year.id,
                    child: Text(year.label),
                  ),
                )
                .toList(),
            icon: Icons.event_repeat_rounded,
            onChanged: (value) => setState(() => _targetYearId = value),
          ),
          const SizedBox(height: 12),
          _DropdownInput<int>(
            label: 'Kelas tujuan',
            value: _targetClassId,
            items: _classes
                .map(
                  (kelas) => DropdownMenuItem<int>(
                    value: kelas.id,
                    child: Text(kelas.nama),
                  ),
                )
                .toList(),
            icon: Icons.school_rounded,
            onChanged: (value) => setState(() => _targetClassId = value),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Siswa kelas asal',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _loadingStudents || _students.isEmpty
                    ? null
                    : () => _toggleAllStudents(!allSelected),
                icon: Icon(
                  allSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                ),
                label: Text(allSelected ? 'Batal semua' : 'Pilih semua'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStudentList(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingPromotion ? null : _promoteStudents,
              icon: _savingPromotion
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upgrade_rounded),
              label: Text(
                _savingPromotion
                    ? 'Menyimpan'
                    : 'Simpan Kenaikan Kelas (${_selectedStudentIds.length})',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_loadingStudents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
      );
    }

    if (_students.isEmpty) {
      return const _EmptyState(
        message: 'Tidak ada siswa pada kelas dan tahun asal ini.',
      );
    }

    return Column(
      children: _students.map((student) {
        final selected = _selectedStudentIds.contains(student.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: CheckboxListTile(
            value: selected,
            activeColor: const Color(0xFF2563EB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              student.nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Text(
              'NIS: ${student.nis}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedStudentIds.add(student.id);
                } else {
                  _selectedStudentIds.remove(student.id);
                }
              });
            },
          ),
        );
      }).toList(),
    );
  }

  String _yearName(int? id) {
    return _firstOrNull(_years.where((item) => item.id == id))?.nama ?? '-';
  }

  String _className(int? id) {
    return _firstOrNull(_classes.where((item) => item.id == id))?.nama ?? '-';
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  int _compareKelas(_KelasOption a, _KelasOption b) {
    final gradeCompare = _gradeRank(a.nama).compareTo(_gradeRank(b.nama));
    if (gradeCompare != 0) return gradeCompare;
    return a.nama.compareTo(b.nama);
  }

  int _gradeRank(String name) {
    final upper = name.toUpperCase();
    if (upper.startsWith('VII ')) return 7;
    if (upper.startsWith('VIII ')) return 8;
    if (upper.startsWith('IX ')) return 9;
    return 99;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1E3A8A),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final IconData icon;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: items.isEmpty ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TahunPelajaranItem {
  const _TahunPelajaranItem({
    required this.id,
    required this.nama,
    required this.isAktif,
  });

  final int id;
  final String nama;
  final bool isAktif;

  String get label => isAktif ? '$nama (Aktif)' : nama;

  factory _TahunPelajaranItem.fromJson(Map json) {
    return _TahunPelajaranItem(
      id: _asInt(json['id']),
      nama: json['nama']?.toString() ?? '-',
      isAktif: json['is_aktif'] == true,
    );
  }
}

class _KelasOption {
  const _KelasOption({required this.id, required this.nama});

  final int id;
  final String nama;

  factory _KelasOption.fromJson(Map json) {
    return _KelasOption(
      id: _asInt(json['id']),
      nama: json['nama_kelas']?.toString() ?? '-',
    );
  }
}

class _SiswaOption {
  const _SiswaOption({required this.id, required this.nama, required this.nis});

  final int id;
  final String nama;
  final String nis;

  factory _SiswaOption.fromJson(Map json) {
    return _SiswaOption(
      id: _asInt(json['id']),
      nama: json['nama']?.toString() ?? '-',
      nis: json['nis']?.toString() ?? '-',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

T? _firstOrNull<T>(Iterable<T> values) {
  if (values.isEmpty) return null;
  return values.first;
}
