import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class AdminJadwalView extends StatefulWidget {
  const AdminJadwalView({super.key});

  @override
  State<AdminJadwalView> createState() => _AdminJadwalViewState();
}

class _AdminJadwalViewState extends State<AdminJadwalView> {
  final ApiService _api = ApiService();
  late Future<_JadwalData> _jadwalFuture;

  @override
  void initState() {
    super.initState();
    _jadwalFuture = _loadJadwal();
  }

  Future<_JadwalData> _loadJadwal() async {
    final responses = await Future.wait([
      _api.get('/api/jadwal/'),
      _api.get('/api/kelas/'),
      _api.get('/api/mata-pelajaran/'),
      _api.get('/api/guru/'),
    ]);

    return _JadwalData(
      jadwal: (responses[0] as List)
          .map((item) => _JadwalItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      kelas: (responses[1] as List)
          .map((item) => _OptionItem.fromJson(item, 'nama_kelas'))
          .toList(),
      mapel: (responses[2] as List)
          .map((item) => _OptionItem.fromJson(item, 'nama_mapel'))
          .toList(),
      guru: (responses[3] as List)
          .map((item) => _GuruOption.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> _openCreatePage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TambahJadwalPage(),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _jadwalFuture = _loadJadwal();
      });
    }
  }

  Future<void> _openEditDay(List<_JadwalItem> schedules) async {
    if (schedules.isEmpty) return;

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TambahJadwalPage(initialSchedules: schedules),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        _jadwalFuture = _loadJadwal();
      });
    }
  }

  Future<void> _deleteJadwal(_JadwalItem jadwal) async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Hapus Jadwal',
      message: 'Hapus jadwal ${jadwal.hari} ${jadwal.jamMulai}?',
      confirmText: 'Hapus',
    );

    if (!confirmed) return;

    try {
      await _api.delete('/api/jadwal/${jadwal.id}');
      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Jadwal berhasil dihapus.',
      );
      setState(() {
        _jadwalFuture = _loadJadwal();
      });
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _jadwalFuture = _loadJadwal();
    });
    try {
      await _jadwalFuture;
    } catch (_) {
      // Error tetap ditampilkan oleh FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Jadwal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola jadwal pelajaran per kelas dan hari',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF434655),
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _openCreatePage,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah Jadwal'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FutureBuilder<_JadwalData>(
                future: _jadwalFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _DataPanel(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return _DataPanel(
                      child: _EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Data jadwal belum bisa dimuat',
                        description: snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      ),
                    );
                  }

                  final data = snapshot.data!;
                  if (data.jadwal.isEmpty) {
                    return const _DataPanel(
                      child: _EmptyState(
                        icon: Icons.schedule_outlined,
                        title: 'Belum ada jadwal',
                        description:
                            'Tambahkan jadwal pertama untuk mengatur presensi kelas.',
                      ),
                    );
                  }

                  return _JadwalGroupedTabs(
                    data: data,
                    onDelete: _deleteJadwal,
                    onEditDay: _openEditDay,
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class TambahJadwalPage extends StatefulWidget {
  const TambahJadwalPage({
    super.key,
    this.initialSchedules = const [],
  });

  final List<_JadwalItem> initialSchedules;

  @override
  State<TambahJadwalPage> createState() => _TambahJadwalPageState();
}

class _TambahJadwalPageState extends State<TambahJadwalPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _jamMulaiController = TextEditingController(text: '07:30');

  bool _isLoading = false;
  bool _isLoadingOptions = true;
  int? _selectedGrade;
  int? _selectedKelasId;
  String? _selectedHari;
  int _jumlahMapel = 1;
  int _breakAfterIndex = 0;
  List<_OptionItem> _kelasOptions = const [];
  List<_OptionItem> _mapelOptions = const [];
  List<_JadwalItem> _existingSchedules = const [];
  final List<_ScheduleEntry> _entries = [];
  final Map<int, List<_GuruOption>> _guruByMapel = {};
  late final List<_JadwalItem> _initialSchedules;

  bool get _isEditMode => _initialSchedules.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initialSchedules = [...widget.initialSchedules]
      ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));
    if (_isEditMode) {
      _hydrateFromInitialSchedules();
    } else {
      _entries.add(_ScheduleEntry());
    }
    _loadOptions();
  }

  @override
  void dispose() {
    _jamMulaiController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final responses = await Future.wait([
        _api.get('/api/kelas/'),
        _api.get('/api/mata-pelajaran/'),
        _api.get('/api/jadwal/'),
      ]);

      if (!mounted) return;
      setState(() {
        _kelasOptions = (responses[0] as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_kelas'))
            .toList();
        if (_selectedKelasId != null) {
          _selectedGrade = _gradeForKelasId(_selectedKelasId!);
        }
        _mapelOptions = (responses[1] as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_mapel'))
            .toList();
        _existingSchedules = (responses[2] as List)
            .map((item) => _JadwalItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _isLoadingOptions = false;
      });
      for (final entry in _entries) {
        final mapelId = entry.mapelId;
        if (mapelId != null) {
          await _loadGuruForMapel(mapelId);
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingOptions = false);
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _hydrateFromInitialSchedules() {
    final first = _initialSchedules.first;
    _selectedKelasId = first.kelasId;
    _selectedHari = first.hari;
    _jamMulaiController.text = first.jamMulai;
    _jumlahMapel = _initialSchedules.length;
    _entries
      ..clear()
      ..addAll(
        _initialSchedules.map(
          (item) => _ScheduleEntry(
            mapelId: item.mapelId,
            guruId: item.guruId,
            lessonHours: _lessonHoursFromSchedule(item),
          ),
        ),
      );
    _breakAfterIndex = _breakIndexFromSchedules(_initialSchedules);
  }

  int? _gradeForKelasId(int kelasId) {
    for (final item in _kelasOptions) {
      if (item.id == kelasId) {
        return _gradeFromClassName(item.label);
      }
    }
    return null;
  }

  List<_OptionItem> _kelasOptionsForSelectedGrade() {
    final grade = _selectedGrade;
    if (grade == null) return const [];
    return _kelasOptions
        .where((item) => _gradeFromClassName(item.label) == grade)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  Future<void> _loadGuruForMapel(int mapelId) async {
    if (_guruByMapel.containsKey(mapelId)) return;
    final response = await _api.get('/api/guru/mapel/$mapelId');
    if (!mounted) return;
    setState(() {
      _guruByMapel[mapelId] = (response as List)
          .map((item) => _GuruOption.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  void _setJumlahMapel(int value) {
    setState(() {
      _jumlahMapel = value;
      while (_entries.length < value) {
        _entries.add(_ScheduleEntry());
      }
      while (_entries.length > value) {
        _entries.removeLast();
      }
      final maxBreakIndex = value <= 1 ? 0 : value - 2;
      if (_breakAfterIndex > maxBreakIndex) {
        _breakAfterIndex = maxBreakIndex;
      }
    });
  }

  Future<void> _pickStartTime() async {
    final current = _parseTime(_jamMulaiController.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: current?.hour ?? 7,
        minute: current?.minute ?? 0,
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _jamMulaiController.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  List<_SchedulePreview> _buildPreview() {
    final start = _parseTime(_jamMulaiController.text);
    if (start == null) return const [];

    final previews = <_SchedulePreview>[];
    var cursor = start;

    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      final end = cursor.add(Duration(minutes: entry.lessonHours * 40));
      previews.add(
        _SchedulePreview(
          entryIndex: index,
          jamMulai: _formatTimeOfDay(cursor),
          jamSelesai: _formatTimeOfDay(end),
          isBreak: false,
        ),
      );
      cursor = end;

      if (index == _breakAfterIndex && index != _entries.length - 1) {
        final breakEnd = cursor.add(const Duration(minutes: 30));
        previews.add(
          _SchedulePreview(
            entryIndex: index,
            jamMulai: _formatTimeOfDay(cursor),
            jamSelesai: _formatTimeOfDay(breakEnd),
            isBreak: true,
          ),
        );
        cursor = breakEnd;
      }
    }

    return previews;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final kelasId = _selectedKelasId;
    final hari = _selectedHari;
    if (kelasId == null || hari == null) return;

    final usedMapel = <int>{};
    for (final entry in _entries) {
      if (entry.mapelId == null || entry.guruId == null) {
        _showError('Lengkapi mata pelajaran dan guru pada semua baris');
        return;
      }
      if (!usedMapel.add(entry.mapelId!)) {
        _showError('Mata pelajaran dalam satu jadwal tidak boleh sama');
        return;
      }
    }

    final previews = _buildPreview().where((item) => !item.isBreak).toList();
    if (previews.length != _entries.length) {
      _showError('Jam mulai tidak valid');
      return;
    }

    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      final conflict = _guruConflictForEntry(index, entry.guruId);
      if (conflict != null) {
        _showError(
          'Guru pada mapel ke-${index + 1} bentrok dengan jadwal '
          '${conflict.hari} ${conflict.jamMulai} - ${conflict.jamSelesai}.',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final items = <Map<String, dynamic>>[];
      for (var index = 0; index < _entries.length; index++) {
        final entry = _entries[index];
        final preview = previews[index];
        items.add({
          'kelas_id': kelasId,
          'mapel_id': entry.mapelId,
          'guru_id': entry.guruId,
          'hari': hari,
          'jam_mulai': preview.jamMulai,
          'jam_selesai': preview.jamSelesai,
        });
      }

      try {
        if (_isEditMode) {
          for (var index = 0; index < items.length; index++) {
            if (index < _initialSchedules.length) {
              await _api.put(
                '/api/jadwal/${_initialSchedules[index].id}',
                items[index],
              );
            } else {
              await _api.post('/api/jadwal/', items[index]);
            }
          }

          if (_initialSchedules.length > items.length) {
            for (final item in _initialSchedules.skip(items.length)) {
              await _api.delete('/api/jadwal/${item.id}');
            }
          }
        } else {
          await _api.post('/api/jadwal/batch', {
            'items': items,
          });
        }
      } catch (error) {
        final message = error.toString();
        if (_isEditMode || !message.contains('Method Not Allowed')) {
          rethrow;
        }

        for (final item in items) {
          await _api.post('/api/jadwal/', item);
        }
      }

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: _isEditMode
            ? 'Jadwal berhasil diperbarui.'
            : 'Jadwal berhasil ditambahkan.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppAlert.error(
      context,
      title: 'Gagal',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final previews = _buildPreview();
    final kelasOptions = _kelasOptionsForSelectedGrade();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Jadwal' : 'Tambah Jadwal'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF191B23),
        elevation: 1,
      ),
      body: SafeArea(
        child: _isLoadingOptions
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionCard(
                        title: 'Rencana Jadwal',
                        children: [
                          DropdownButtonFormField<int>(
                            value: _selectedGrade,
                            decoration: _inputDecoration(
                              label: 'Tingkat Kelas',
                              icon: Icons.school_rounded,
                            ),
                            items: const [7, 8, 9]
                                .map(
                                  (grade) => DropdownMenuItem<int>(
                                    value: grade,
                                    child: Text('Kelas $grade'),
                                  ),
                                )
                                .toList(),
                            onChanged: _isEditMode
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedGrade = value;
                                      final selectedKelasId = _selectedKelasId;
                                      if (selectedKelasId != null &&
                                          _gradeForKelasId(selectedKelasId) !=
                                              value) {
                                        _selectedKelasId = null;
                                        _selectedHari = null;
                                      }
                                    });
                                  },
                            validator: (value) {
                              if (value == null) {
                                return 'Tingkat kelas wajib dipilih';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            value: _selectedKelasId,
                            decoration: _inputDecoration(
                              label: 'Nama Kelas',
                              icon: Icons.class_rounded,
                            ),
                            items: kelasOptions
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _selectedGrade == null || _isEditMode
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedKelasId = value;
                                      if (!_availableDaysForSelectedClass()
                                          .contains(_selectedHari)) {
                                        _selectedHari = null;
                                      }
                                    });
                                  },
                            validator: (value) {
                              if (_selectedGrade == null) {
                                return 'Pilih tingkat kelas terlebih dahulu';
                              }
                              if (kelasOptions.isEmpty) {
                                return 'Belum ada kelas pada tingkat ini';
                              }
                              if (value == null) return 'Kelas wajib dipilih';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedHari,
                            decoration: _inputDecoration(
                              label: 'Hari',
                              icon: Icons.calendar_month_rounded,
                            ),
                            items: _availableDaysForSelectedClass()
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedHari = value);
                            },
                            validator: (value) {
                              if (_selectedKelasId == null) {
                                return 'Pilih kelas terlebih dahulu';
                              }
                              if (_availableDaysForSelectedClass().isEmpty) {
                                return 'Semua hari kelas ini sudah memiliki jadwal';
                              }
                              if (value == null) return 'Hari wajib dipilih';
                              return null;
                            },
                          ),
                          if (!_isEditMode &&
                              _selectedKelasId != null &&
                              _usedDaysForSelectedClass().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Hari yang sudah memiliki jadwal tidak ditampilkan. '
                              'Untuk mengubah jadwal hari tersebut, gunakan tombol edit '
                              'pada data jadwal.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF737686),
                                  ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _jamMulaiController,
                            keyboardType: TextInputType.datetime,
                            decoration: _inputDecoration(
                              label: 'Jam Mulai',
                              icon: Icons.access_time_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: _pickStartTime,
                                icon: const Icon(Icons.schedule_rounded),
                                tooltip: 'Pilih jam mulai',
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (_parseTime(value ?? '') == null) {
                                return 'Format jam harus HH:MM';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<int>(
                            value: _jumlahMapel,
                            decoration: _inputDecoration(
                              label: 'Jumlah Mata Pelajaran',
                              icon: Icons.format_list_numbered_rounded,
                            ),
                            items: List.generate(8, (index) => index + 1)
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item,
                                    child: Text('$item mata pelajaran'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              _setJumlahMapel(value);
                            },
                          ),
                          if (_jumlahMapel > 1) ...[
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              value: _breakAfterIndex,
                              decoration: _inputDecoration(
                                label: 'Istirahat 30 Menit Setelah',
                                icon: Icons.free_breakfast_rounded,
                              ),
                              items: List.generate(
                                _jumlahMapel - 1,
                                (index) => index,
                              )
                                  .map(
                                    (item) => DropdownMenuItem<int>(
                                      value: item,
                                      child: Text('Mapel ke-${item + 1}'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _breakAfterIndex = value);
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: 'Mata Pelajaran',
                        children: List.generate(
                          _entries.length,
                          (index) => Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _entries.length - 1 ? 0 : 16,
                            ),
                            child: _ScheduleEntryEditor(
                              index: index,
                              entry: _entries[index],
                              mapelOptions: _filteredMapelOptions(index),
                              guruOptions: _guruOptionsForEntry(_entries[index]),
                              guruDisabledReason: (guruId) {
                                final conflict =
                                    _guruConflictForEntry(index, guruId);
                                if (conflict == null) return null;
                                return 'Bentrok ${conflict.jamMulai} - ${conflict.jamSelesai}';
                              },
                              onMapelChanged: (value) async {
                                setState(() {
                                  _entries[index].mapelId = value;
                                  _entries[index].guruId = null;
                                });
                                if (value != null) {
                                  await _loadGuruForMapel(value);
                                }
                              },
                              onGuruChanged: (value) {
                                setState(() => _entries[index].guruId = value);
                              },
                              onLessonHoursChanged: (value) {
                                if (value == null) return;
                                setState(() => _entries[index].lessonHours = value);
                              },
                            ),
                          ),
                        ),
                      ),
                      if (previews.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Preview Jam',
                          children: previews
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PreviewRow(
                                    preview: item,
                                    entry: item.isBreak ? null : _entries[item.entryIndex],
                                    mapelName: item.isBreak
                                        ? 'Istirahat'
                                        : _labelForMapel(
                                            _entries[item.entryIndex].mapelId,
                                          ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_isLoading ? 'Menyimpan' : 'Simpan Jadwal'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  List<_OptionItem> _filteredMapelOptions(int currentIndex) {
    final usedByOtherEntries = <int>{};
    for (var index = 0; index < _entries.length; index++) {
      if (index == currentIndex) continue;
      final mapelId = _entries[index].mapelId;
      if (mapelId != null) usedByOtherEntries.add(mapelId);
    }
    return _mapelOptions
        .where((item) => !usedByOtherEntries.contains(item.id))
        .toList();
  }

  List<_GuruOption> _guruOptionsForEntry(_ScheduleEntry entry) {
    final mapelId = entry.mapelId;
    if (mapelId == null) return const [];
    return _guruByMapel[mapelId] ?? const [];
  }

  List<String> _availableDaysForSelectedClass() {
    if (_isEditMode) return _days;
    final usedDays = _usedDaysForSelectedClass();
    return _days.where((day) => !usedDays.contains(day)).toList();
  }

  Set<String> _usedDaysForSelectedClass() {
    final kelasId = _selectedKelasId;
    if (kelasId == null) return const <String>{};
    return _existingSchedules
        .where((item) => item.kelasId == kelasId)
        .map((item) => item.hari)
        .where((hari) => hari.isNotEmpty)
        .toSet();
  }

  _JadwalItem? _guruConflictForEntry(int entryIndex, int? guruId) {
    if (guruId == null) return null;
    final hari = _selectedHari;
    if (hari == null) return null;

    final preview = _previewForEntry(entryIndex);
    if (preview == null) return null;
    final start = _parseTime(preview.jamMulai);
    final end = _parseTime(preview.jamSelesai);
    if (start == null || end == null) return null;

    final ignoredIds = _initialSchedules.map((item) => item.id).toSet();
    for (final item in _existingSchedules) {
      if (ignoredIds.contains(item.id)) continue;
      if (item.guruId != guruId || item.hari != hari) continue;

      final existingStart = _parseTime(item.jamMulai);
      final existingEnd = _parseTime(item.jamSelesai);
      if (existingStart == null || existingEnd == null) continue;
      if (_timeRangesOverlap(start, end, existingStart, existingEnd)) {
        return item;
      }
    }
    return null;
  }

  _SchedulePreview? _previewForEntry(int entryIndex) {
    for (final item in _buildPreview()) {
      if (!item.isBreak && item.entryIndex == entryIndex) return item;
    }
    return null;
  }

  String _labelForMapel(int? mapelId) {
    if (mapelId == null) return 'Mata pelajaran belum dipilih';
    return _mapelOptions
        .firstWhere(
          (item) => item.id == mapelId,
          orElse: () => _OptionItem(id: mapelId, label: 'Mapel ID $mapelId'),
        )
        .label;
  }
}

class _ScheduleEntryEditor extends StatelessWidget {
  const _ScheduleEntryEditor({
    required this.index,
    required this.entry,
    required this.mapelOptions,
    required this.guruOptions,
    required this.guruDisabledReason,
    required this.onMapelChanged,
    required this.onGuruChanged,
    required this.onLessonHoursChanged,
  });

  final int index;
  final _ScheduleEntry entry;
  final List<_OptionItem> mapelOptions;
  final List<_GuruOption> guruOptions;
  final String? Function(int guruId) guruDisabledReason;
  final ValueChanged<int?> onMapelChanged;
  final ValueChanged<int?> onGuruChanged;
  final ValueChanged<int?> onLessonHoursChanged;

  @override
  Widget build(BuildContext context) {
    final mapelValue = mapelOptions.any((item) => item.id == entry.mapelId)
        ? entry.mapelId
        : null;
    final guruValue = guruOptions.any((item) => item.id == entry.guruId)
        ? entry.guruId
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mapel ke-${index + 1}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF191B23),
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: mapelValue,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: _inputDecoration(
              label: 'Nama Pelajaran',
              icon: Icons.menu_book_rounded,
            ),
            items: mapelOptions
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: _DropdownText(item.label),
                  ),
                )
                .toList(),
            onChanged: onMapelChanged,
            validator: (value) {
              if (value == null) return 'Mata pelajaran wajib dipilih';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: guruValue,
            isExpanded: true,
            menuMaxHeight: 360,
            decoration: _inputDecoration(
              label: 'Nama Guru',
              icon: Icons.person_rounded,
            ),
            items: guruOptions
                .map((item) {
                  final disabledReason = guruDisabledReason(item.id);
                  final isDisabled = disabledReason != null;
                  return DropdownMenuItem<int>(
                    value: item.id,
                    enabled: !isDisabled,
                    child: _GuruDropdownItem(
                      name: item.nama,
                      disabledReason: disabledReason,
                    ),
                  );
                })
                .toList(),
            onChanged: guruOptions.isEmpty ? null : onGuruChanged,
            validator: (value) {
              if (value == null) return 'Guru wajib dipilih';
              return null;
            },
          ),
          if (entry.mapelId != null && guruOptions.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Belum ada guru yang terdaftar mengajar mapel ini.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFDC2626),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: entry.lessonHours,
            isExpanded: true,
            menuMaxHeight: 320,
            decoration: _inputDecoration(
              label: 'Jumlah Jam Pelajaran',
              icon: Icons.timer_rounded,
            ),
            items: List.generate(6, (index) => index + 1)
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item,
                    child: _DropdownText('$item JP (${item * 40} menit)'),
                  ),
                )
                .toList(),
            onChanged: onLessonHoursChanged,
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.preview,
    required this.entry,
    required this.mapelName,
  });

  final _SchedulePreview preview;
  final _ScheduleEntry? entry;
  final String mapelName;

  @override
  Widget build(BuildContext context) {
    final isBreak = preview.isBreak;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isBreak ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isBreak ? Icons.free_breakfast_rounded : Icons.schedule_rounded,
            color: isBreak ? const Color(0xFFEA580C) : const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mapelName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                '${preview.jamMulai} - ${preview.jamSelesai}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF737686),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuruDropdownItem extends StatelessWidget {
  const _GuruDropdownItem({
    required this.name,
    required this.disabledReason,
  });

  final String name;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final isDisabled = disabledReason != null;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDisabled ? const Color(0xFF94A3B8) : null,
              fontWeight: isDisabled ? FontWeight.w600 : null,
            ),
          ),
        ),
        if (isDisabled) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              disabledReason!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DropdownText extends StatelessWidget {
  const _DropdownText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _JadwalGroupedTabs extends StatefulWidget {
  const _JadwalGroupedTabs({
    required this.data,
    required this.onDelete,
    required this.onEditDay,
  });

  final _JadwalData data;
  final ValueChanged<_JadwalItem> onDelete;
  final ValueChanged<List<_JadwalItem>> onEditDay;

  @override
  State<_JadwalGroupedTabs> createState() => _JadwalGroupedTabsState();
}

class _JadwalGroupedTabsState extends State<_JadwalGroupedTabs> {
  int _selectedGrade = 7;

  @override
  Widget build(BuildContext context) {
    final schedulesByGrade = <int, List<_JadwalItem>>{
      7: [],
      8: [],
      9: [],
    };

    for (final item in widget.data.jadwal) {
      final kelasName = widget.data.labelForKelas(item.kelasId);
      final grade = _gradeFromClassName(kelasName);
      if (grade != null) {
        schedulesByGrade[grade]?.add(item);
      }
    }

    final selectedItems =
        schedulesByGrade[_selectedGrade] ?? const <_JadwalItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GradeTabBar(
          selectedGrade: _selectedGrade,
          counts: {
            for (final entry in schedulesByGrade.entries)
              entry.key: entry.value.length,
          },
          onChanged: (grade) {
            setState(() => _selectedGrade = grade);
          },
        ),
        const SizedBox(height: 18),
        if (selectedItems.isEmpty)
          _DataPanel(
            child: _EmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Belum ada jadwal kelas $_selectedGrade',
              description:
                  'Tambahkan jadwal untuk kelas $_selectedGrade agar tampil di bagian ini.',
            ),
          )
        else
          ..._buildClassGroups(selectedItems).map(
            (group) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _JadwalClassGroupCard(
                kelasName: widget.data.labelForKelas(group.kelasId),
                schedules: group.items,
                data: widget.data,
                onDelete: widget.onDelete,
                onEditDay: widget.onEditDay,
              ),
            ),
          ),
      ],
    );
  }

  List<_JadwalClassGroup> _buildClassGroups(List<_JadwalItem> items) {
    final grouped = <int, List<_JadwalItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.kelasId, () => []).add(item);
    }

    final groups = grouped.entries
        .map((entry) => _JadwalClassGroup(kelasId: entry.key, items: entry.value))
        .toList()
      ..sort((a, b) => widget.data
          .labelForKelas(a.kelasId)
          .compareTo(widget.data.labelForKelas(b.kelasId)));

    for (final group in groups) {
      group.items.sort((a, b) {
        final dayCompare = _dayIndex(a.hari).compareTo(_dayIndex(b.hari));
        if (dayCompare != 0) return dayCompare;
        return a.jamMulai.compareTo(b.jamMulai);
      });
    }

    return groups;
  }
}

class _GradeTabBar extends StatelessWidget {
  const _GradeTabBar({
    required this.selectedGrade,
    required this.counts,
    required this.onChanged,
  });

  final int selectedGrade;
  final Map<int, int> counts;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.35)),
      ),
      child: Row(
        children: [7, 8, 9].map((grade) {
          final isSelected = selectedGrade == grade;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onChanged(grade),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Kelas $grade',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF737686),
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${counts[grade] ?? 0} jadwal',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF737686),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _JadwalClassGroupCard extends StatelessWidget {
  const _JadwalClassGroupCard({
    required this.kelasName,
    required this.schedules,
    required this.data,
    required this.onDelete,
    required this.onEditDay,
  });

  final String kelasName;
  final List<_JadwalItem> schedules;
  final _JadwalData data;
  final ValueChanged<_JadwalItem> onDelete;
  final ValueChanged<List<_JadwalItem>> onEditDay;

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<_JadwalItem>>{};
    for (final item in schedules) {
      byDay.putIfAbsent(item.hari, () => []).add(item);
    }

    final days = byDay.keys.toList()
      ..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kelasName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF191B23),
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${schedules.length} jadwal pelajaran',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF737686),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...days.map((day) {
            final daySchedules = byDay[day]!
              ..sort((a, b) => a.jamMulai.compareTo(b.jamMulai));
            return Padding(
              padding: EdgeInsets.only(bottom: day == days.last ? 0 : 14),
              child: _JadwalDaySection(
                day: day,
                schedules: daySchedules,
                data: data,
                onDelete: onDelete,
                onEdit: () => onEditDay(daySchedules),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _JadwalDaySection extends StatelessWidget {
  const _JadwalDaySection({
    required this.day,
    required this.schedules,
    required this.data,
    required this.onDelete,
    required this.onEdit,
  });

  final String day;
  final List<_JadwalItem> schedules;
  final _JadwalData data;
  final ValueChanged<_JadwalItem> onDelete;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                day,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                color: const Color(0xFF2563EB),
                tooltip: 'Edit jadwal hari $day',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...schedules.map(
            (item) => Padding(
              padding: EdgeInsets.only(
                bottom: item == schedules.last ? 0 : 10,
              ),
              child: _JadwalMiniCard(
                jadwal: item,
                mapelName: data.labelForMapel(item.mapelId),
                guruName: data.labelForGuru(item.guruId),
                onDelete: () => onDelete(item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JadwalMiniCard extends StatelessWidget {
  const _JadwalMiniCard({
    required this.jadwal,
    required this.mapelName,
    required this.guruName,
    required this.onDelete,
  });

  final _JadwalItem jadwal;
  final String mapelName;
  final String guruName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEFF6FF),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mapelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF191B23),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  guruName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF737686),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${jadwal.jamMulai} - ${jadwal.jamSelesai}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: const Color(0xFFDC2626),
            tooltip: 'Hapus jadwal',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _JadwalClassGroup {
  const _JadwalClassGroup({
    required this.kelasId,
    required this.items,
  });

  final int kelasId;
  final List<_JadwalItem> items;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF191B23),
                ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 22),
    prefixIconConstraints: const BoxConstraints(
      minWidth: 46,
      minHeight: 46,
    ),
    contentPadding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
    filled: true,
    fillColor: const Color(0xFFF8FAFF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: const Color(0xFFC3C6D7).withOpacity(0.45),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(
        color: Color(0xFF2563EB),
        width: 1.4,
      ),
    ),
  );
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 48, color: const Color(0xFF737686)),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF737686),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _JadwalData {
  const _JadwalData({
    required this.jadwal,
    required this.kelas,
    required this.mapel,
    required this.guru,
  });

  final List<_JadwalItem> jadwal;
  final List<_OptionItem> kelas;
  final List<_OptionItem> mapel;
  final List<_GuruOption> guru;

  String labelForKelas(int id) => kelas
      .firstWhere(
        (item) => item.id == id,
        orElse: () => _OptionItem(id: id, label: 'ID kelas $id'),
      )
      .label;

  String labelForMapel(int id) => mapel
      .firstWhere(
        (item) => item.id == id,
        orElse: () => _OptionItem(id: id, label: 'Mapel ID $id'),
      )
      .label;

  String labelForGuru(int id) => guru
      .firstWhere(
        (item) => item.id == id,
        orElse: () => _GuruOption(id: id, nama: 'Guru ID $id'),
      )
      .nama;
}

class _JadwalItem {
  const _JadwalItem({
    required this.id,
    required this.kelasId,
    required this.mapelId,
    required this.guruId,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
  });

  final int id;
  final int kelasId;
  final int mapelId;
  final int guruId;
  final String hari;
  final String jamMulai;
  final String jamSelesai;

  factory _JadwalItem.fromJson(Map<String, dynamic> json) {
    return _JadwalItem(
      id: _intFromJson(json['id']) ?? 0,
      kelasId: _intFromJson(json['kelas_id']) ?? 0,
      mapelId: _intFromJson(json['mapel_id']) ?? 0,
      guruId: _intFromJson(json['guru_id']) ?? 0,
      hari: json['hari'] ?? '',
      jamMulai: json['jam_mulai'] ?? '',
      jamSelesai: json['jam_selesai'] ?? '',
    );
  }
}

class _ScheduleEntry {
  _ScheduleEntry({
    this.mapelId,
    this.guruId,
    this.lessonHours = 1,
  });

  int? mapelId;
  int? guruId;
  int lessonHours;
}

class _SchedulePreview {
  const _SchedulePreview({
    required this.entryIndex,
    required this.jamMulai,
    required this.jamSelesai,
    required this.isBreak,
  });

  final int entryIndex;
  final String jamMulai;
  final String jamSelesai;
  final bool isBreak;
}

class _OptionItem {
  const _OptionItem({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;

  factory _OptionItem.fromJson(dynamic json, String labelKey) {
    final item = json as Map<String, dynamic>;
    return _OptionItem(
      id: _intFromJson(item['id']) ?? 0,
      label: item[labelKey] ?? '',
    );
  }
}

class _GuruOption {
  const _GuruOption({
    required this.id,
    required this.nama,
  });

  final int id;
  final String nama;

  factory _GuruOption.fromJson(Map<String, dynamic> json) {
    return _GuruOption(
      id: _intFromJson(json['id']) ?? 0,
      nama: json['nama'] ?? '',
    );
  }
}

DateTime? _parseTime(String value) {
  final normalized = value.trim().replaceAll('.', ':');
  final parts = normalized.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return DateTime(2026, 1, 1, hour, minute);
}

String _formatTimeOfDay(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}

int _dayIndex(String day) {
  final index = _days.indexOf(day);
  return index == -1 ? 99 : index;
}

int _lessonHoursFromSchedule(_JadwalItem item) {
  final start = _parseTime(item.jamMulai);
  final end = _parseTime(item.jamSelesai);
  if (start == null || end == null) return 1;

  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) return 1;
  return (minutes / 40).round().clamp(1, 8).toInt();
}

int _breakIndexFromSchedules(List<_JadwalItem> schedules) {
  if (schedules.length <= 1) return 0;

  for (var index = 0; index < schedules.length - 1; index++) {
    final currentEnd = _parseTime(schedules[index].jamSelesai);
    final nextStart = _parseTime(schedules[index + 1].jamMulai);
    if (currentEnd == null || nextStart == null) continue;
    if (nextStart.difference(currentEnd).inMinutes >= 30) {
      return index;
    }
  }

  return 0;
}

bool _timeRangesOverlap(
  DateTime startA,
  DateTime endA,
  DateTime startB,
  DateTime endB,
) {
  return startA.isBefore(endB) && startB.isBefore(endA);
}

int? _gradeFromClassName(String name) {
  final normalized = name.trim().toUpperCase();
  if (normalized.isEmpty) return null;

  final firstToken = normalized.split(RegExp(r'\s+')).first;
  if (firstToken == 'VII' || firstToken == '7') return 7;
  if (firstToken == 'VIII' || firstToken == '8') return 8;
  if (firstToken == 'IX' || firstToken == '9') return 9;

  if (RegExp(r'\bVII\b').hasMatch(normalized)) return 7;
  if (RegExp(r'\bVIII\b').hasMatch(normalized)) return 8;
  if (RegExp(r'\bIX\b').hasMatch(normalized)) return 9;
  if (RegExp(r'\b7\b').hasMatch(normalized)) return 7;
  if (RegExp(r'\b8\b').hasMatch(normalized)) return 8;
  if (RegExp(r'\b9\b').hasMatch(normalized)) return 9;
  return null;
}

const _days = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
