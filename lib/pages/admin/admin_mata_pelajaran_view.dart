import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class AdminMataPelajaranView extends StatefulWidget {
  const AdminMataPelajaranView({super.key});

  @override
  State<AdminMataPelajaranView> createState() => _AdminMataPelajaranViewState();
}

class _AdminMataPelajaranViewState extends State<AdminMataPelajaranView> {
  final ApiService _api = ApiService();
  late Future<_MapelListData> _mapelFuture;
  Set<String> _existingMapelNames = {};

  @override
  void initState() {
    super.initState();
    _mapelFuture = _loadMapel();
  }

  Future<_MapelListData> _loadMapel() async {
    final responses = await Future.wait([
      _api.get('/api/mata-pelajaran/'),
      _api.get('/api/guru/'),
    ]);
    final items = (responses[0] as List)
        .map((item) => _MapelItem.fromJson(item as Map<String, dynamic>))
        .toList();
    _existingMapelNames = items.map((item) => item.namaMapel).toSet();
    return _MapelListData(
      mapel: items,
      guruByMapelId: _guruNamesByMapelId(responses[1] as List),
    );
  }

  Future<void> _openCreateMapelPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TambahMataPelajaranPage(
          existingMapel: _existingMapelNames,
        ),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _mapelFuture = _loadMapel();
      });
    }
  }

  Future<void> _openEditMapelPage(_MapelItem mapel) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _EditMataPelajaranPage(
          mapel: mapel,
          existingMapel: _existingMapelNames,
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        _mapelFuture = _loadMapel();
      });
    }
  }

  Future<void> _deleteMapel(_MapelItem mapel) async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Hapus Mata Pelajaran?',
      message:
          '${mapel.namaMapel} akan dihapus. Pastikan mata pelajaran ini tidak sedang dipakai oleh jadwal.',
      confirmText: 'Hapus',
    );
    if (!confirmed) return;

    try {
      await _api.delete('/api/mata-pelajaran/${mapel.id}');
      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Mata pelajaran ${mapel.namaMapel} berhasil dihapus.',
      );
      if (!mounted) return;
      setState(() {
        _mapelFuture = _loadMapel();
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
      _mapelFuture = _loadMapel();
    });
    try {
      await _mapelFuture;
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
                'Data Mata Pelajaran',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola daftar mata pelajaran untuk penugasan guru dan jadwal',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF434655),
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _openCreateMapelPage,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Tambah Mata Pelajaran'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FutureBuilder<_MapelListData>(
                future: _mapelFuture,
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
                        title: 'Data mata pelajaran belum bisa dimuat',
                        description: snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      ),
                    );
                  }

                  final data = snapshot.data ?? _MapelListData.empty();
                  final mapel = data.mapel;
                  if (mapel.isEmpty) {
                    return const _DataPanel(
                      child: _EmptyState(
                        icon: Icons.menu_book_outlined,
                        title: 'Belum ada mata pelajaran',
                        description:
                            'Tambahkan mata pelajaran pertama untuk menyusun penugasan guru dan jadwal.',
                      ),
                    );
                  }

                  return Column(
                    children: mapel
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MapelCard(
                              mapel: item,
                              guruNames: data.guruNamesFor(item.id),
                              onEdit: () => _openEditMapelPage(item),
                              onDelete: () => _deleteMapel(item),
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

class TambahMataPelajaranPage extends StatefulWidget {
  const TambahMataPelajaranPage({
    super.key,
    required this.existingMapel,
  });

  final Set<String> existingMapel;

  @override
  State<TambahMataPelajaranPage> createState() =>
      _TambahMataPelajaranPageState();
}

class _TambahMataPelajaranPageState extends State<TambahMataPelajaranPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final List<TextEditingController> _namaMapelControllers = [
    TextEditingController(),
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    for (final controller in _namaMapelControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addMapelInput() {
    setState(() {
      _namaMapelControllers.add(TextEditingController());
    });
  }

  void _removeMapelInput(int index) {
    if (_namaMapelControllers.length == 1) return;
    final controller = _namaMapelControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final mapelNames = _namaMapelControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    final normalizedNames = mapelNames.map(_normalizeMapelName).toList();
    final duplicatedInput = <String>{};
    final seen = <String>{};
    for (var i = 0; i < normalizedNames.length; i++) {
      if (!seen.add(normalizedNames[i])) {
        duplicatedInput.add(mapelNames[i]);
      }
    }

    if (duplicatedInput.isNotEmpty) {
      await AppAlert.warning(
        context,
        title: 'Nama Duplikat',
        message:
            'Ada mata pelajaran yang sama dalam form: ${duplicatedInput.join(', ')}.',
      );
      return;
    }

    final existingNormalized = widget.existingMapel.map(_normalizeMapelName);
    final alreadyExists = mapelNames
        .where((name) => existingNormalized.contains(_normalizeMapelName(name)))
        .toList();
    if (alreadyExists.isNotEmpty) {
      await AppAlert.warning(
        context,
        title: 'Mata Pelajaran Sudah Ada',
        message:
            '${alreadyExists.join(', ')} sudah tersimpan dan tidak bisa ditambahkan lagi.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      for (final namaMapel in mapelNames) {
        await _api.post('/api/mata-pelajaran/', {
          'nama_mapel': namaMapel,
        });
      }

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: mapelNames.length == 1
            ? 'Mata pelajaran berhasil ditambahkan.'
            : '${mapelNames.length} mata pelajaran berhasil ditambahkan.',
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

  List<Widget> _buildMapelInputs() {
    final fields = <Widget>[];
    for (var i = 0; i < _namaMapelControllers.length; i++) {
      final index = i;
      fields.add(
        _MapelInputRow(
          controller: _namaMapelControllers[index],
          index: index,
          canRemove: _namaMapelControllers.length > 1,
          onRemove: () => _removeMapelInput(index),
        ),
      );
      if (index != _namaMapelControllers.length - 1) {
        fields.add(const SizedBox(height: 12));
      }
    }
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Tambah Mata Pelajaran'),
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
                const _MapelHeaderCard(),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Informasi Mata Pelajaran',
                  children: [
                    ..._buildMapelInputs(),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _addMapelInput,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Tambah Input'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: BorderSide(
                            color: const Color(0xFF2563EB).withOpacity(0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
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
                    label: Text(
                      _isLoading
                          ? 'Menyimpan'
                          : _namaMapelControllers.length <= 1
                              ? 'Simpan Mata Pelajaran'
                              : 'Simpan ${_namaMapelControllers.length} Mata Pelajaran',
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
        ),
      ),
    );
  }
}

class _MapelInputRow extends StatelessWidget {
  const _MapelInputRow({
    required this.controller,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration(
              label: 'Nama Mata Pelajaran ${index + 1}',
              icon: Icons.menu_book_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama mata pelajaran wajib diisi';
              }
              if (value.trim().length < 3) {
                return 'Nama mata pelajaran terlalu pendek';
              }
              return null;
            },
          ),
        ),
        if (canRemove) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Tooltip(
              message: 'Hapus input',
              child: Material(
                color: const Color(0xFFDC2626).withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EditMataPelajaranPage extends StatefulWidget {
  const _EditMataPelajaranPage({
    super.key,
    required this.mapel,
    required this.existingMapel,
  });

  final _MapelItem mapel;
  final Set<String> existingMapel;

  @override
  State<_EditMataPelajaranPage> createState() =>
      _EditMataPelajaranPageState();
}

class _EditMataPelajaranPageState extends State<_EditMataPelajaranPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  late final TextEditingController _namaMapelController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaMapelController =
        TextEditingController(text: widget.mapel.namaMapel);
  }

  @override
  void dispose() {
    _namaMapelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _api.put('/api/mata-pelajaran/${widget.mapel.id}', {
        'nama_mapel': _namaMapelController.text.trim(),
      });

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Mata pelajaran berhasil diperbarui.',
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
        title: const Text('Edit Mata Pelajaran'),
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
                const _MapelHeaderCard(),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Informasi Mata Pelajaran',
                  children: [
                    TextFormField(
                      controller: _namaMapelController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Nama Mata Pelajaran',
                        icon: Icons.menu_book_rounded,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return 'Nama mata pelajaran wajib diisi';
                        }
                        if (text.length < 3) {
                          return 'Nama mata pelajaran terlalu pendek';
                        }
                        final normalized = _normalizeMapelName(text);
                        final current =
                            _normalizeMapelName(widget.mapel.namaMapel);
                        final duplicated = widget.existingMapel
                            .map(_normalizeMapelName)
                            .any((item) => item == normalized);
                        if (normalized != current && duplicated) {
                          return 'Nama mata pelajaran sudah digunakan';
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

class _MapelHeaderCard extends StatelessWidget {
  const _MapelHeaderCard();

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
              Icons.menu_book_rounded,
              size: 34,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Mata Pelajaran',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF191B23),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nama harus unik agar jadwal dan penugasan guru tetap rapi',
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

class _MapelCard extends StatelessWidget {
  const _MapelCard({
    required this.mapel,
    required this.guruNames,
    required this.onEdit,
    required this.onDelete,
  });

  final _MapelItem mapel;
  final List<String> guruNames;
  final VoidCallback onEdit;
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
                  mapel.namaMapel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF191B23),
                      ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: guruNames.isEmpty
                            ? const Color(0xFFF8FAFF)
                            : const Color(0xFFEAFBF2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: guruNames.isEmpty
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFFB7F1D4),
                        ),
                      ),
                      child: Text(
                        guruNames.isEmpty ? 'Belum ada guru' : 'Ada guru',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: guruNames.isEmpty
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF078B4F),
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ),
                    if (guruNames.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(
                          guruNames.join(', '),
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
          const SizedBox(width: 10),
          _MapelActionButton(
            tooltip: 'Edit mata pelajaran',
            icon: Icons.edit_rounded,
            color: const Color(0xFF2563EB),
            onPressed: onEdit,
          ),
          const SizedBox(width: 7),
          _MapelActionButton(
            tooltip: 'Hapus mata pelajaran',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFDC2626),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _MapelActionButton extends StatelessWidget {
  const _MapelActionButton({
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
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

String _normalizeMapelName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _MapelListData {
  const _MapelListData({
    required this.mapel,
    required this.guruByMapelId,
  });

  final List<_MapelItem> mapel;
  final Map<int, List<String>> guruByMapelId;

  factory _MapelListData.empty() {
    return const _MapelListData(
      mapel: [],
      guruByMapelId: {},
    );
  }

  List<String> guruNamesFor(int mapelId) {
    final names = guruByMapelId[mapelId] ?? const <String>[];
    return names.toList()..sort();
  }
}

class _MapelItem {
  const _MapelItem({
    required this.id,
    required this.namaMapel,
  });

  final int id;
  final String namaMapel;

  factory _MapelItem.fromJson(Map<String, dynamic> json) {
    return _MapelItem(
      id: json['id'],
      namaMapel: json['nama_mapel'] ?? '',
    );
  }
}

Map<int, List<String>> _guruNamesByMapelId(List response) {
  final result = <int, List<String>>{};
  for (final raw in response) {
    final item = raw as Map<String, dynamic>;
    final guruName = item['nama']?.toString() ?? '';
    if (guruName.isEmpty) continue;

    for (final mapelId in _intListFromJson(item, 'mapel_ids', 'mapel_id')) {
      result.putIfAbsent(mapelId, () => <String>[]).add(guruName);
    }
  }
  return result;
}

List<int> _intListFromJson(
  Map<String, dynamic> json,
  String listKey,
  String singleKey,
) {
  final value = json[listKey];
  if (value is List) {
    return value
        .map((item) => item is int ? item : int.tryParse(item.toString()))
        .whereType<int>()
        .toList();
  }

  final singleValue = json[singleKey];
  if (singleValue == null) return [];

  final parsed = singleValue is int
      ? singleValue
      : int.tryParse(singleValue.toString());
  return parsed == null ? [] : [parsed];
}
