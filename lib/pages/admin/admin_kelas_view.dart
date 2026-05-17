import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class AdminKelasView extends StatefulWidget {
  const AdminKelasView({super.key});

  @override
  State<AdminKelasView> createState() => _AdminKelasViewState();
}

class _AdminKelasViewState extends State<AdminKelasView> {
  final ApiService _api = ApiService();
  late Future<_KelasListData> _kelasFuture;
  Set<String> _existingKelasNames = {};

  @override
  void initState() {
    super.initState();
    _kelasFuture = _loadKelas();
  }

  Future<_KelasListData> _loadKelas() async {
    final responses = await Future.wait([
      _api.get('/api/kelas/'),
      _api.get('/api/guru/'),
    ]);
    final data = _KelasListData(
      kelas: (responses[0] as List)
          .map((item) => _KelasItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      guruById: _guruMapFromResponse(responses[1] as List),
    );
    _existingKelasNames = data.kelas.map((item) => item.namaKelas).toSet();
    return data;
  }

  Future<void> _openCreateKelasPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TambahKelasPage(
          existingKelas: _existingKelasNames,
        ),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _kelasFuture = _loadKelas();
      });
    }
  }

  Future<void> _openEditKelasPage(_KelasItem kelas) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditKelasPage(
          kelas: kelas,
          existingKelas: _existingKelasNames,
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        _kelasFuture = _loadKelas();
      });
    }
  }

  Future<void> _deleteKelas(_KelasItem kelas) async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Hapus Kelas?',
      message:
          'Kelas ${kelas.namaKelas} akan dihapus. Pastikan kelas ini tidak sedang dipakai oleh siswa atau jadwal.',
      confirmText: 'Hapus',
    );
    if (!confirmed) return;

    try {
      await _api.delete('/api/kelas/${kelas.id}');
      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Kelas ${kelas.namaKelas} berhasil dihapus.',
      );
      if (!mounted) return;
      setState(() {
        _kelasFuture = _loadKelas();
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
      _kelasFuture = _loadKelas();
    });
    try {
      await _kelasFuture;
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
                'Data Kelas',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola daftar kelas untuk data siswa, wali kelas, dan jadwal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF434655),
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _openCreateKelasPage,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah Kelas'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FutureBuilder<_KelasListData>(
                future: _kelasFuture,
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
                        title: 'Data kelas belum bisa dimuat',
                        description: snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      ),
                    );
                  }

                  final data = snapshot.data ?? _KelasListData.empty();
                  final kelas = data.kelas;
                  if (kelas.isEmpty) {
                    return const _DataPanel(
                      child: _EmptyState(
                        icon: Icons.class_outlined,
                        title: 'Belum ada kelas',
                        description:
                            'Tambahkan kelas pertama sebelum mengisi data siswa dan jadwal.',
                      ),
                    );
                  }

                  return _KelasGroupedTabs(
                    data: data,
                    onEdit: _openEditKelasPage,
                    onDelete: _deleteKelas,
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

class TambahKelasPage extends StatefulWidget {
  const TambahKelasPage({
    super.key,
    required this.existingKelas,
  });

  final Set<String> existingKelas;

  @override
  State<TambahKelasPage> createState() => _TambahKelasPageState();
}

class _TambahKelasPageState extends State<TambahKelasPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  bool _isLoading = false;
  String? _selectedTingkat;
  final Set<String> _selectedRombels = {};
  late Set<String> _existingKelas;

  @override
  void initState() {
    super.initState();
    _existingKelas = widget.existingKelas;
    _loadExistingKelas();
  }

  Future<void> _loadExistingKelas() async {
    try {
      final response = await _api.get('/api/kelas/');
      if (!mounted) return;
      final names = (response as List)
          .map((item) => _KelasItem.fromJson(item as Map<String, dynamic>))
          .map((item) => item.namaKelas)
          .toSet();

      setState(() {
        _existingKelas = names;
        final tingkat = _selectedTingkat;
        if (tingkat != null) {
          _selectedRombels.removeWhere(
            (rombel) => _isKelasUnavailable('$tingkat $rombel'),
          );
        }
      });
    } catch (_) {
      // Cache dari halaman sebelumnya tetap dipakai jika refresh opsi gagal.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final tingkat = _selectedTingkat;
    if (tingkat == null) return;
    if (_selectedRombels.isEmpty) {
      await AppAlert.warning(
        context,
        title: 'Pilih Kelas',
        message: 'Pilih minimal satu kelas yang ingin ditambahkan.',
      );
      return;
    }

    final kelasNames = _selectedNamaKelas();
    final unavailable = kelasNames.where(_isKelasUnavailable).toList();
    if (unavailable.isNotEmpty) {
      await AppAlert.warning(
        context,
        title: 'Kelas Sudah Ada',
        message:
            '${unavailable.join(', ')} sudah tersimpan dan tidak bisa ditambahkan lagi.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      for (final namaKelas in kelasNames) {
        await _api.post('/api/kelas/', {
          'nama_kelas': namaKelas,
        });
      }

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message:
            '${kelasNames.length} kelas berhasil ditambahkan: ${kelasNames.join(', ')}.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Tambah Kelas'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF191B23),
        elevation: 1,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _KelasHeaderCard(),
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Informasi Kelas',
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedTingkat,
                        decoration: _inputDecoration(
                          label: 'Tingkat Kelas',
                          icon: Icons.class_rounded,
                        ),
                        items: _tingkatKelasOptions
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text('Kelas $item'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTingkat = value;
                            if (value != null) {
                              _selectedRombels.removeWhere(
                                (rombel) =>
                                    _isKelasUnavailable('$value $rombel'),
                              );
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
                      _RombelMultiPicker(
                        enabled: _selectedTingkat != null,
                        selectedRombels: _selectedRombels,
                        isUnavailable: (rombel) {
                          final tingkat = _selectedTingkat;
                          return tingkat != null &&
                              _isKelasUnavailable('$tingkat $rombel');
                        },
                        onToggle: (rombel) {
                          if (_selectedTingkat == null) return;
                          setState(() {
                            if (_selectedRombels.contains(rombel)) {
                              _selectedRombels.remove(rombel);
                            } else {
                              _selectedRombels.add(rombel);
                            }
                          });
                        },
                        onSelectRange: (start, end) {
                          if (_selectedTingkat == null) return;
                          setState(() {
                            final startIndex = _rombelOptions.indexOf(start);
                            final endIndex = _rombelOptions.indexOf(end);
                            if (startIndex == -1 || endIndex == -1) return;
                            final from =
                                startIndex <= endIndex ? startIndex : endIndex;
                            final to =
                                startIndex <= endIndex ? endIndex : startIndex;
                            for (final rombel
                                in _rombelOptions.sublist(from, to + 1)) {
                              if (!_isKelasUnavailable(
                                '${_selectedTingkat!} $rombel',
                              )) {
                                _selectedRombels.add(rombel);
                              }
                            }
                          });
                        },
                        onClear: () {
                          setState(_selectedRombels.clear);
                        },
                      ),
                      const SizedBox(height: 14),
                      _KelasPreviewCard(
                        namaKelas: _selectedTingkat == null
                            ? const []
                            : _selectedNamaKelas(),
                        emptyLabel: _selectedTingkat == null
                            ? 'Pilih tingkat kelas terlebih dahulu'
                            : 'Pilih satu atau beberapa kelas',
                      ),
                    ],
                  ),
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
                      label: Text(
                        _isLoading
                            ? 'Menyimpan'
                            : _selectedRombels.length <= 1
                                ? 'Simpan Kelas'
                                : 'Simpan ${_selectedRombels.length} Kelas',
                      ),
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
          ],
        ),
      ),
    );
  }

  List<String> _selectedNamaKelas() {
    final tingkat = _selectedTingkat;
    if (tingkat == null) return const [];
    final selected = _selectedRombels.toList()
      ..sort((a, b) => _rombelOptions.indexOf(a).compareTo(
            _rombelOptions.indexOf(b),
          ));
    return selected.map((rombel) => '$tingkat $rombel').toList();
  }

  bool _isKelasUnavailable(String namaKelas) {
    final normalized = _normalizeKelasName(namaKelas);
    return _existingKelas.map(_normalizeKelasName).contains(normalized);
  }
}

class _EditKelasPage extends StatefulWidget {
  const _EditKelasPage({
    super.key,
    required this.kelas,
    required this.existingKelas,
  });

  final _KelasItem kelas;
  final Set<String> existingKelas;

  @override
  State<_EditKelasPage> createState() => _EditKelasPageState();
}

class _EditKelasPageState extends State<_EditKelasPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  late final TextEditingController _namaKelasController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaKelasController =
        TextEditingController(text: widget.kelas.namaKelas);
  }

  @override
  void dispose() {
    _namaKelasController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.put('/api/kelas/${widget.kelas.id}', {
        'nama_kelas': _namaKelasController.text.trim(),
      });

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Data kelas berhasil diperbarui.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Edit Kelas'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF191B23),
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  title: 'Informasi Kelas',
                  children: [
                    TextFormField(
                      controller: _namaKelasController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        label: 'Nama Kelas',
                        icon: Icons.class_rounded,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Nama kelas wajib diisi';
                        }
                        final normalized = _normalizeKelasName(text);
                        final current =
                            _normalizeKelasName(widget.kelas.namaKelas);
                        final duplicated = widget.existingKelas
                            .map(_normalizeKelasName)
                            .any((item) => item == normalized);
                        if (normalized != current && duplicated) {
                          return 'Nama kelas sudah digunakan';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Wali kelas tetap diatur melalui menu edit data guru.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
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
                    label: Text(_isLoading ? 'Menyimpan' : 'Simpan Perubahan'),
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
}

class _KelasHeaderCard extends StatelessWidget {
  const _KelasHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEFF6FF),
            ),
            child: const Icon(
              Icons.class_rounded,
              size: 34,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Kelas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF191B23),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nama kelas harus unik agar relasi siswa dan jadwal tetap jelas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF737686),
                ),
          ),
        ],
      ),
    );
  }
}

class _RombelMultiPicker extends StatelessWidget {
  const _RombelMultiPicker({
    required this.enabled,
    required this.selectedRombels,
    required this.isUnavailable,
    required this.onToggle,
    required this.onSelectRange,
    required this.onClear,
  });

  final bool enabled;
  final Set<String> selectedRombels;
  final bool Function(String rombel) isUnavailable;
  final ValueChanged<String> onToggle;
  final void Function(String start, String end) onSelectRange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sort_by_alpha_rounded,
                color: Color(0xFF4B5563),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pilihan Kelas',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF4B5563),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (selectedRombels.isNotEmpty)
                TextButton(
                  onPressed: enabled ? onClear : null,
                  child: const Text('Bersihkan'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _rombelOptions.map((rombel) {
              final unavailable = enabled && isUnavailable(rombel);
              final selected = selectedRombels.contains(rombel);
              return FilterChip(
                label: Text(unavailable ? '$rombel sudah ada' : rombel),
                selected: selected,
                onSelected: !enabled || unavailable
                    ? null
                    : (_) => onToggle(rombel),
                selectedColor: const Color(0xFFDBEAFE),
                checkmarkColor: const Color(0xFF2563EB),
                disabledColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: unavailable
                      ? const Color(0xFF9CA3AF)
                      : selected
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF374151),
                  fontWeight: FontWeight.w800,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF2563EB).withOpacity(0.35)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RangeChip(
                label: 'A-C',
                enabled: enabled,
                onTap: () => onSelectRange('A', 'C'),
              ),
              _RangeChip(
                label: 'D-I',
                enabled: enabled,
                onTap: () => onSelectRange('D', 'I'),
              ),
              _RangeChip(
                label: 'J-L',
                enabled: enabled,
                onTap: () => onSelectRange('J', 'L'),
              ),
            ],
          ),
          if (!enabled) ...[
            const SizedBox(height: 10),
            Text(
              'Pilih tingkat kelas dulu agar rombel bisa dipilih.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF737686),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(label),
      onPressed: enabled ? onTap : null,
      backgroundColor: const Color(0xFFEFF6FF),
      disabledColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: enabled ? const Color(0xFF1D4ED8) : const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: enabled
              ? const Color(0xFF2563EB).withOpacity(0.18)
              : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }
}

class _KelasPreviewCard extends StatelessWidget {
  const _KelasPreviewCard({
    required this.namaKelas,
    required this.emptyLabel,
  });

  final List<String> namaKelas;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final isReady = namaKelas.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReady ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReady
              ? const Color(0xFF2563EB).withOpacity(0.28)
              : const Color(0xFFC3C6D7).withOpacity(0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isReady ? Colors.white : const Color(0xFFEFF3FF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReady ? Icons.done_all_rounded : Icons.badge_rounded,
              color:
                  isReady ? const Color(0xFF2563EB) : const Color(0xFF737686),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady
                      ? '${namaKelas.length} kelas akan dibuat'
                      : 'Nama kelas otomatis',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF737686),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  isReady ? namaKelas.join(', ') : emptyLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isReady
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF737686),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
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
  const _DataPanel({
    required this.child,
  });

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

class _KelasGroupedTabs extends StatefulWidget {
  const _KelasGroupedTabs({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  final _KelasListData data;
  final ValueChanged<_KelasItem> onEdit;
  final ValueChanged<_KelasItem> onDelete;

  @override
  State<_KelasGroupedTabs> createState() => _KelasGroupedTabsState();
}

class _KelasGroupedTabsState extends State<_KelasGroupedTabs> {
  int _selectedGrade = 7;

  @override
  Widget build(BuildContext context) {
    final groups = _KelasGroups.fromItems(widget.data.kelas);
    final kelasByGrade = <int, List<_KelasItem>>{
      7: groups.kelas7,
      8: groups.kelas8,
      9: groups.kelas9,
    };
    final selectedKelas =
        kelasByGrade[_selectedGrade] ?? const <_KelasItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GradeTabBar(
          selectedGrade: _selectedGrade,
          counts: {
            for (final entry in kelasByGrade.entries)
              entry.key: entry.value.length,
          },
          onChanged: (grade) {
            setState(() => _selectedGrade = grade);
          },
        ),
        const SizedBox(height: 18),
        _KelasGroupCard(
          title: _kelasGroupTitle(_selectedGrade),
          subtitle: 'Daftar kelas tingkat $_selectedGrade',
          accentColor: _kelasGroupColor(_selectedGrade),
          kelas: selectedKelas,
          guruById: widget.data.guruById,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
      ],
    );
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
                        '${counts[grade] ?? 0} kelas',
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

class _KelasGroupCard extends StatelessWidget {
  const _KelasGroupCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.kelas,
    required this.guruById,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final List<_KelasItem> kelas;
  final Map<int, String> guruById;
  final ValueChanged<_KelasItem> onEdit;
  final ValueChanged<_KelasItem> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080B3558),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: accentColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF191B23),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${kelas.length} kelas',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (kelas.isEmpty)
            _EmptyKelasGroup(accentColor: accentColor)
          else
            Column(
              children: [
                for (final item in kelas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _KelasMiniCard(
                      kelas: item,
                      accentColor: accentColor,
                      waliKelasName: item.waliKelasId == null
                          ? null
                          : guruById[item.waliKelasId!],
                      onEdit: () => onEdit(item),
                      onDelete: () => onDelete(item),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KelasMiniCard extends StatelessWidget {
  const _KelasMiniCard({
    required this.kelas,
    required this.accentColor,
    required this.waliKelasName,
    required this.onEdit,
    required this.onDelete,
  });

  final _KelasItem kelas;
  final Color accentColor;
  final String? waliKelasName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.class_rounded, color: accentColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kelas.namaKelas,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF191B23),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        kelas.waliKelasId == null
                            ? 'Belum ada wali'
                            : 'Ada wali',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: kelas.waliKelasId == null
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF078B4F),
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    if (kelas.waliKelasId != null)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          waliKelasName ?? 'Wali tidak ditemukan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniActionButton(
                tooltip: 'Edit kelas',
                icon: Icons.edit_rounded,
                color: accentColor,
                onPressed: onEdit,
              ),
              const SizedBox(width: 6),
              _MiniActionButton(
                tooltip: 'Hapus kelas',
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFDC2626),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }
}

class _EmptyKelasGroup extends StatelessWidget {
  const _EmptyKelasGroup({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: accentColor, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Belum ada kelas pada tingkat ini',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KelasGroups {
  const _KelasGroups({
    required this.kelas7,
    required this.kelas8,
    required this.kelas9,
  });

  final List<_KelasItem> kelas7;
  final List<_KelasItem> kelas8;
  final List<_KelasItem> kelas9;

  factory _KelasGroups.fromItems(List<_KelasItem> items) {
    final kelas7 = <_KelasItem>[];
    final kelas8 = <_KelasItem>[];
    final kelas9 = <_KelasItem>[];

    for (final item in items) {
      final grade = _gradeFromClassName(item.namaKelas);
      if (grade == 7) {
        kelas7.add(item);
      } else if (grade == 8) {
        kelas8.add(item);
      } else if (grade == 9) {
        kelas9.add(item);
      }
    }

    int compareKelas(_KelasItem a, _KelasItem b) {
      return a.namaKelas.toLowerCase().compareTo(b.namaKelas.toLowerCase());
    }

    kelas7.sort(compareKelas);
    kelas8.sort(compareKelas);
    kelas9.sort(compareKelas);

    return _KelasGroups(
      kelas7: kelas7,
      kelas8: kelas8,
      kelas9: kelas9,
    );
  }
}

class _KelasListData {
  const _KelasListData({
    required this.kelas,
    required this.guruById,
  });

  final List<_KelasItem> kelas;
  final Map<int, String> guruById;

  factory _KelasListData.empty() {
    return const _KelasListData(kelas: [], guruById: {});
  }
}

String _kelasGroupTitle(int grade) {
  if (grade == 8) return 'Kelas VIII';
  if (grade == 9) return 'Kelas IX';
  return 'Kelas VII';
}

Color _kelasGroupColor(int grade) {
  if (grade == 8) return const Color(0xFF10B981);
  if (grade == 9) return const Color(0xFFF59E0B);
  return const Color(0xFF2563EB);
}

int? _gradeFromClassName(String name) {
  final normalized = name.trim().toUpperCase();
  if (RegExp(r'(^|\s)(VII|7)(\s|$)').hasMatch(normalized)) return 7;
  if (RegExp(r'(^|\s)(VIII|8)(\s|$)').hasMatch(normalized)) return 8;
  if (RegExp(r'(^|\s)(IX|9)(\s|$)').hasMatch(normalized)) return 9;
  if (normalized.startsWith('VII')) return 7;
  if (normalized.startsWith('VIII')) return 8;
  if (normalized.startsWith('IX')) return 9;
  if (normalized.startsWith('7')) return 7;
  if (normalized.startsWith('8')) return 8;
  if (normalized.startsWith('9')) return 9;
  return null;
}

String _normalizeKelasName(String value) {
  return value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}

const _tingkatKelasOptions = ['VII', 'VIII', 'IX'];

const _rombelOptions = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
];

Map<int, String> _guruMapFromResponse(List response) {
  final labels = <int, String>{};
  for (final raw in response) {
    final item = raw as Map<String, dynamic>;
    final id = _intFromJson(item['id']);
    if (id != null) {
      labels[id] = item['nama']?.toString() ?? '';
    }
  }
  return labels;
}

class _KelasItem {
  const _KelasItem({
    required this.id,
    required this.namaKelas,
    this.waliKelasId,
  });

  final int id;
  final String namaKelas;
  final int? waliKelasId;

  factory _KelasItem.fromJson(Map<String, dynamic> json) {
    return _KelasItem(
      id: json['id'],
      namaKelas: json['nama_kelas'] ?? '',
      waliKelasId: _intFromJson(json['wali_kelas_id']),
    );
  }
}

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
