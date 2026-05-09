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

                  final sorted = [...data.jadwal]
                    ..sort((a, b) {
                      final dayCompare = _dayIndex(a.hari).compareTo(_dayIndex(b.hari));
                      if (dayCompare != 0) return dayCompare;
                      return a.jamMulai.compareTo(b.jamMulai);
                    });

                  return Column(
                    children: sorted
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _JadwalCard(
                              jadwal: item,
                              kelasName: data.labelForKelas(item.kelasId),
                              mapelName: data.labelForMapel(item.mapelId),
                              guruName: data.labelForGuru(item.guruId),
                              onDelete: () => _deleteJadwal(item),
                            ),
                          ),
                        )
                        .toList(),
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
  const TambahJadwalPage({super.key});

  @override
  State<TambahJadwalPage> createState() => _TambahJadwalPageState();
}

class _TambahJadwalPageState extends State<TambahJadwalPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _jamMulaiController = TextEditingController(text: '07:00');

  bool _isLoading = false;
  bool _isLoadingOptions = true;
  int? _selectedKelasId;
  String? _selectedHari;
  int _jumlahMapel = 1;
  int _breakAfterIndex = 0;
  List<_OptionItem> _kelasOptions = const [];
  List<_OptionItem> _mapelOptions = const [];
  final List<_ScheduleEntry> _entries = [_ScheduleEntry()];
  final Map<int, List<_GuruOption>> _guruByMapel = {};

  @override
  void initState() {
    super.initState();
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
      ]);

      if (!mounted) return;
      setState(() {
        _kelasOptions = (responses[0] as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_kelas'))
            .toList();
        _mapelOptions = (responses[1] as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_mapel'))
            .toList();
        _isLoadingOptions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingOptions = false);
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
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
        await _api.post('/api/jadwal/batch', {
          'items': items,
        });
      } catch (error) {
        final message = error.toString();
        if (!message.contains('Method Not Allowed')) {
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
        message: 'Jadwal berhasil ditambahkan.',
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

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Tambah Jadwal'),
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
                            value: _selectedKelasId,
                            decoration: _inputDecoration(
                              label: 'Nama Kelas',
                              icon: Icons.class_rounded,
                            ),
                            items: _kelasOptions
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.id,
                                    child: Text(item.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedKelasId = value);
                            },
                            validator: (value) {
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
                            items: _days
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
                              if (value == null) return 'Hari wajib dipilih';
                              return null;
                            },
                          ),
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
    required this.onMapelChanged,
    required this.onGuruChanged,
    required this.onLessonHoursChanged,
  });

  final int index;
  final _ScheduleEntry entry;
  final List<_OptionItem> mapelOptions;
  final List<_GuruOption> guruOptions;
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
            decoration: _inputDecoration(
              label: 'Nama Pelajaran',
              icon: Icons.menu_book_rounded,
            ),
            items: mapelOptions
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(item.label),
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
            decoration: _inputDecoration(
              label: 'Nama Guru',
              icon: Icons.person_rounded,
            ),
            items: guruOptions
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item.id,
                    child: Text(item.nama),
                  ),
                )
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
            decoration: _inputDecoration(
              label: 'Jumlah Jam Pelajaran',
              icon: Icons.timer_rounded,
            ),
            items: List.generate(6, (index) => index + 1)
                .map(
                  (item) => DropdownMenuItem<int>(
                    value: item,
                    child: Text('$item JP (${item * 40} menit)'),
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

class _JadwalCard extends StatelessWidget {
  const _JadwalCard({
    required this.jadwal,
    required this.kelasName,
    required this.mapelName,
    required this.guruName,
    required this.onDelete,
  });

  final _JadwalItem jadwal;
  final String kelasName;
  final String mapelName;
  final String guruName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEFF6FF),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$kelasName - $mapelName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
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
                  '${jadwal.hari} | ${jadwal.jamMulai} - ${jadwal.jamSelesai}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF737686),
                      ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_rounded),
            color: const Color(0xFFDC2626),
            tooltip: 'Hapus jadwal',
          ),
        ],
      ),
    );
  }
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
    prefixIcon: Icon(icon),
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
  int? mapelId;
  int? guruId;
  int lessonHours = 1;
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

const _days = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
