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
    return _KelasListData(
      kelas: (responses[0] as List)
          .map((item) => _KelasItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      guruById: _guruMapFromResponse(responses[1] as List),
    );
  }

  Future<void> _openCreateKelasPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TambahKelasPage(),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _kelasFuture = _loadKelas();
      });
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

                  final groups = _KelasGroups.fromItems(kelas);
                  return Column(
                    children: [
                      _KelasGroupCard(
                        title: 'Kelas VII',
                        subtitle: 'Daftar kelas tingkat 7',
                        accentColor: const Color(0xFF2563EB),
                        kelas: groups.kelas7,
                        guruById: data.guruById,
                      ),
                      const SizedBox(height: 16),
                      _KelasGroupCard(
                        title: 'Kelas VIII',
                        subtitle: 'Daftar kelas tingkat 8',
                        accentColor: const Color(0xFF10B981),
                        kelas: groups.kelas8,
                        guruById: data.guruById,
                      ),
                      const SizedBox(height: 16),
                      _KelasGroupCard(
                        title: 'Kelas IX',
                        subtitle: 'Daftar kelas tingkat 9',
                        accentColor: const Color(0xFFF59E0B),
                        kelas: groups.kelas9,
                        guruById: data.guruById,
                      ),
                    ],
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
  const TambahKelasPage({super.key});

  @override
  State<TambahKelasPage> createState() => _TambahKelasPageState();
}

class _TambahKelasPageState extends State<TambahKelasPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _namaKelasController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _namaKelasController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.post('/api/kelas/', {
        'nama_kelas': _namaKelasController.text.trim(),
      });

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Kelas berhasil ditambahkan.',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _KelasHeaderCard(),
                const SizedBox(height: 24),
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
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama kelas wajib diisi';
                        }
                        if (value.trim().length < 2) {
                          return 'Nama kelas terlalu pendek';
                        }
                        return null;
                      },
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
                    label: Text(_isLoading ? 'Menyimpan' : 'Simpan Kelas'),
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

class _KelasGroupCard extends StatelessWidget {
  const _KelasGroupCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.kelas,
    required this.guruById,
  });

  final String title;
  final String subtitle;
  final Color accentColor;
  final List<_KelasItem> kelas;
  final Map<int, String> guruById;

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
  });

  final _KelasItem kelas;
  final Color accentColor;
  final String? waliKelasName;

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
            child: Text(
              kelas.namaKelas,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF191B23),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  kelas.waliKelasId == null ? 'Belum ada wali' : 'Ada wali',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: kelas.waliKelasId == null
                            ? const Color(0xFF64748B)
                            : const Color(0xFF078B4F),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (kelas.waliKelasId != null) ...[
                const SizedBox(height: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 118),
                  child: Text(
                    waliKelasName ?? 'Wali tidak ditemukan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ],
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
