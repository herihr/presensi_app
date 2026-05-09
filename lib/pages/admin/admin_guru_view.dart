import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class AdminGuruView extends StatefulWidget {
  const AdminGuruView({super.key});

  @override
  State<AdminGuruView> createState() => _AdminGuruViewState();
}

class _AdminGuruViewState extends State<AdminGuruView> {
  final ApiService _api = ApiService();
  late Future<Object?> _guruFuture;

  @override
  void initState() {
    super.initState();
    _guruFuture = _loadGuru();
  }

  Future<_GuruListData> _loadGuru() async {
    final responses = await Future.wait([
      _api.get('/api/guru/'),
      _api.get('/api/mata-pelajaran/'),
      _api.get('/api/kelas/'),
    ]);
    return _GuruListData(
      guru: (responses[0] as List)
          .map((item) => _GuruItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      mapelById: _labelMapFromResponse(responses[1] as List, 'nama_mapel'),
      kelasById: _labelMapFromResponse(responses[2] as List, 'nama_kelas'),
    );
  }

  Future<void> _openCreateGuruPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TambahGuruPage(),
      ),
    );

    if (created == true && mounted) {
      setState(() {
        _guruFuture = _loadGuru();
      });
    }
  }

  Future<void> _openEditGuruPage(_GuruItem guru) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TambahGuruPage(guru: guru),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        _guruFuture = _loadGuru();
      });
    }
  }

  Future<void> _deleteGuru(_GuruItem guru) async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Hapus Guru',
      message: 'Hapus data ${guru.nama}?',
      confirmText: 'Hapus',
    );

    if (!confirmed) return;

    try {
      await _api.delete('/api/guru/${guru.id}');

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Data guru berhasil dihapus.',
      );
      setState(() {
        _guruFuture = _loadGuru();
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Guru',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF191B23),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kelola akun, mata pelajaran, dan wali kelas guru',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF434655),
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _openCreateGuruPage,
                icon: const Icon(Icons.person_add_alt_rounded),
                label: const Text('Tambah Guru'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<Object?>(
              future: _guruFuture,
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
                      title: 'Data guru belum bisa dimuat',
                      description: snapshot.error.toString().replaceFirst('Exception: ', ''),
                    ),
                  );
                }

                final data = _GuruListData.fromSnapshot(snapshot.data);
                final guru = data.guru;
                if (guru.isEmpty) {
                  return const _DataPanel(
                    child: _EmptyState(
                      icon: Icons.person_outline,
                      title: 'Belum ada data guru',
                      description: 'Tambahkan guru pertama untuk mulai mengatur jadwal dan presensi.',
                    ),
                  );
                }

                return Column(
                  children: guru
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GuruCard(
                            guru: item,
                            mapelNames: data.mapelNamesFor(item),
                            kelasAsuhName: data.kelasAsuhNameFor(item),
                            onEdit: () => _openEditGuruPage(item),
                            onDelete: () => _deleteGuru(item),
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
    );
  }
}

class TambahGuruPage extends StatefulWidget {
  const TambahGuruPage({
    super.key,
    this.guru,
  });

  final _GuruItem? guru;

  @override
  State<TambahGuruPage> createState() => _TambahGuruPageState();
}

class _TambahGuruPageState extends State<TambahGuruPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isPickingPhoto = false;
  bool _obscurePassword = true;
  String? _selectedFotoPath;
  final Set<int> _selectedMapelIds = {};
  int? _selectedKelasId;
  List<_OptionItem> _mapelOptions = const [];
  List<_OptionItem> _kelasOptions = const [];

  bool get _isEditMode => widget.guru != null;

  @override
  void initState() {
    super.initState();
    final guru = widget.guru;
    if (guru != null) {
      _namaController.text = guru.nama;
      _nipController.text = guru.nip;
      _emailController.text = guru.email;
      _selectedFotoPath = guru.fotoUrl;
      _selectedMapelIds.addAll(guru.mapelIds);
      _selectedKelasId = guru.kelasAsuhIds.isEmpty ? null : guru.kelasAsuhIds.first;
    }
    _loadOptions();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final responses = await Future.wait([
        _api.get('/api/mata-pelajaran/'),
        _api.get('/api/kelas/'),
      ]);

      if (!mounted) return;
      setState(() {
        _mapelOptions = (responses[0] as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_mapel'))
            .toList();
        _kelasOptions = (responses[1] as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_kelas'))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mapelOptions = _fallbackMapelOptions;
        _kelasOptions = const [];
      });
    }
  }

  Future<void> _pickPhoto() async {
    if (_isPickingPhoto) return;

    setState(() => _isPickingPhoto = true);

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (image == null || !mounted) return;
      setState(() {
        _selectedFotoPath = image.path;
      });
    } on MissingPluginException {
      _showPhotoPickerError(
        'Plugin foto belum aktif. Stop aplikasi lalu jalankan ulang dengan flutter run.',
      );
    } on PlatformException catch (error) {
      _showPhotoPickerError(error.message ?? 'Galeri foto tidak bisa dibuka');
    } catch (error) {
      _showPhotoPickerError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  void _showPhotoPickerError(String message) {
    if (!mounted) return;
    AppAlert.error(
      context,
      title: 'Gagal Membuka Foto',
      message: message,
    );
  }

  void _clearPhoto() {
    setState(() {
      _selectedFotoPath = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMapelIds.isEmpty) {
      await AppAlert.warning(
        context,
        title: 'Data Belum Lengkap',
        message: 'Pilih minimal satu mata pelajaran yang diajar.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final mapelIds = _selectedMapelIds.toList()..sort();

      final payload = {
        'nama': _namaController.text.trim(),
        'nip': _nipController.text.trim(),
        'email': _emailController.text.trim(),
        'foto_url': _selectedFotoPath,
        'mapel_ids': mapelIds,
        'kelas_asuh_id': _selectedKelasId,
      };

      if (!_isEditMode || _passwordController.text.isNotEmpty) {
        payload['password'] = _passwordController.text;
      }

      if (_isEditMode) {
        await _api.put('/api/guru/${widget.guru!.id}', payload);
      } else {
        await _api.post('/api/guru/', payload);
      }

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: _isEditMode
            ? 'Data guru berhasil diperbarui.'
            : 'Data guru berhasil ditambahkan.',
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
    final currentGuruId = widget.guru?.id;
    final availableKelasOptions = _kelasOptions
        .where(
          (item) =>
              item.waliKelasId == null || item.waliKelasId == currentGuruId,
        )
        .toList();
    final kelasDropdownValue = availableKelasOptions.any(
      (item) => item.id == _selectedKelasId,
    )
        ? _selectedKelasId
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Data Guru' : 'Tambah Data Guru'),
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
                _PhotoPreview(
                  photoPath: _selectedFotoPath,
                  nameController: _namaController,
                  onPickPhoto: _pickPhoto,
                  onClearPhoto: _clearPhoto,
                  isPickingPhoto: _isPickingPhoto,
                ),
                const SizedBox(height: 24),
                _SectionCard(
                  title: 'Identitas Guru',
                  children: [
                    _TextField(
                      controller: _namaController,
                      label: 'Nama Guru',
                      icon: Icons.person_rounded,
                      onChanged: (_) => setState(() {}),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 14),
                    _TextField(
                      controller: _nipController,
                      label: 'NIP',
                      icon: Icons.badge_rounded,
                      keyboardType: TextInputType.number,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 14),
                    _TextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.mail_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!value.contains('@')) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _TextField(
                      controller: _passwordController,
                      label: _isEditMode ? 'Password Baru' : 'Password',
                      icon: Icons.lock_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                      validator: (value) {
                        if (_isEditMode && (value == null || value.isEmpty)) {
                          return null;
                        }
                        return _requiredValidator(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Penugasan',
                  children: [
                    _MultiOptionSelector(
                      title: 'Mata Pelajaran yang Diajar',
                      description: 'Pilih satu atau beberapa mata pelajaran',
                      icon: Icons.menu_book_rounded,
                      options: _mapelOptions,
                      selectedIds: _selectedMapelIds,
                      emptyText: 'Belum ada mata pelajaran. Tambahkan dari menu Mapel.',
                      onToggle: (id) {
                        setState(() {
                          if (_selectedMapelIds.contains(id)) {
                            _selectedMapelIds.remove(id);
                          } else {
                            _selectedMapelIds.add(id);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int?>(
                      value: kelasDropdownValue,
                      decoration: _inputDecoration(
                        label: 'Wali Kelas',
                        icon: Icons.class_rounded,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tidak menjadi wali kelas'),
                        ),
                        ...availableKelasOptions.map(
                          (item) => DropdownMenuItem<int?>(
                            value: item.id,
                            child: Text(item.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedKelasId = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih maksimal satu kelas. Kelas yang sudah punya wali tidak ditampilkan.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF737686),
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
                          : _isEditMode
                              ? 'Simpan Perubahan'
                              : 'Simpan Guru',
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

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field ini wajib diisi';
    }
    return null;
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.photoPath,
    required this.nameController,
    required this.onPickPhoto,
    required this.onClearPhoto,
    required this.isPickingPhoto,
  });

  final String? photoPath;
  final TextEditingController nameController;
  final VoidCallback onPickPhoto;
  final VoidCallback onClearPhoto;
  final bool isPickingPhoto;

  @override
  Widget build(BuildContext context) {
    final name = nameController.text.trim();
    final initial = name.isEmpty ? 'G' : name[0].toUpperCase();
    final photoProvider = _photoProvider(photoPath);

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
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFFEFF6FF),
            backgroundImage: photoProvider,
            child: photoProvider == null
                ? Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            'Foto Guru',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF191B23),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            photoPath == null
                ? 'Pilih foto dari galeri HP'
                : 'Foto lokal sudah dipilih',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF737686),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isPickingPhoto ? null : onPickPhoto,
                  icon: isPickingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_rounded),
                  label: Text(isPickingPhoto ? 'Membuka Galeri' : 'Pilih Foto'),
                ),
              ),
              if (photoPath != null) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: onClearPhoto,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Hapus foto',
                ),
              ],
            ],
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _MultiOptionSelector extends StatelessWidget {
  const _MultiOptionSelector({
    required this.title,
    required this.description,
    required this.icon,
    required this.options,
    required this.selectedIds,
    required this.emptyText,
    required this.onToggle,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<_OptionItem> options;
  final Set<int> selectedIds;
  final String emptyText;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: const Color(0xFF737686)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF191B23),
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF737686),
                            ),
                      ),
                    ],
                  ),
                ),
                if (selectedIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${selectedIds.length} dipilih',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF737686),
                      ),
                ),
              ),
            )
          else
            ...options.map(
              (item) => CheckboxListTile(
                value: selectedIds.contains(item.id),
                onChanged: (_) => onToggle(item.id),
                dense: true,
                visualDensity: VisualDensity.compact,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: const Color(0xFF2563EB),
                title: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
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

ImageProvider? _photoProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
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

class _GuruCard extends StatefulWidget {
  const _GuruCard({
    required this.guru,
    required this.mapelNames,
    required this.kelasAsuhName,
    required this.onEdit,
    required this.onDelete,
  });

  final _GuruItem guru;
  final List<String> mapelNames;
  final String? kelasAsuhName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_GuruCard> createState() => _GuruCardState();
}

class _GuruCardState extends State<_GuruCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final guru = widget.guru;
    final photoProvider = _photoProvider(guru.fotoUrl);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _isExpanded
              ? const Color(0xFF2563EB).withOpacity(0.38)
              : const Color(0xFFC3C6D7).withOpacity(0.45),
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _isExpanded
                ? const Color(0x1A2563EB)
                : const Color(0x080B3558),
            blurRadius: _isExpanded ? 20 : 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFEFF6FF),
                      backgroundImage: photoProvider,
                      child: photoProvider == null
                          ? Text(
                              guru.nama.isEmpty
                                  ? 'G'
                                  : guru.nama[0].toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guru.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF191B23),
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            guru.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF737686),
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _TinyMeta(
                                icon: Icons.badge_outlined,
                                label: guru.nip,
                                maxWidth: 118,
                              ),
                              _TinyMeta(
                                icon: Icons.menu_book_rounded,
                                label: '${guru.mapelIds.length} mapel',
                                maxWidth: 82,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 36,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MinimalIconButton(
                            icon: Icons.edit_rounded,
                            color: const Color(0xFF2563EB),
                            tooltip: 'Edit guru',
                            onPressed: widget.onEdit,
                          ),
                          const SizedBox(height: 6),
                          _MinimalIconButton(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFDC2626),
                            tooltip: 'Hapus guru',
                            onPressed: widget.onDelete,
                          ),
                          const SizedBox(height: 3),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: _GuruAssignmentDetails(
                    mapelNames: widget.mapelNames,
                    kelasAsuhName: widget.kelasAsuhName,
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                  firstCurve: Curves.easeOutCubic,
                  secondCurve: Curves.easeOutCubic,
                  sizeCurve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({
    required this.icon,
    required this.label,
    this.maxWidth,
  });

  final IconData icon;
  final String label;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalIconButton extends StatelessWidget {
  const _MinimalIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _GuruAssignmentDetails extends StatelessWidget {
  const _GuruAssignmentDetails({
    required this.mapelNames,
    required this.kelasAsuhName,
  });

  final List<String> mapelNames;
  final String? kelasAsuhName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AssignmentSection(
              icon: Icons.menu_book_rounded,
              title: 'Mata pelajaran yang diajar',
              children: mapelNames.isEmpty
                  ? const ['Belum ada mata pelajaran']
                  : mapelNames,
            ),
            const SizedBox(height: 14),
            _AssignmentSection(
              icon: Icons.class_rounded,
              title: 'Wali kelas',
              children: [kelasAsuhName ?? 'Bukan wali kelas'],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentSection extends StatelessWidget {
  const _AssignmentSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: children
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          item,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuruListData {
  const _GuruListData({
    required this.guru,
    required this.mapelById,
    required this.kelasById,
  });

  final List<_GuruItem> guru;
  final Map<int, String> mapelById;
  final Map<int, String> kelasById;

  factory _GuruListData.empty() {
    return const _GuruListData(
      guru: [],
      mapelById: {},
      kelasById: {},
    );
  }

  factory _GuruListData.fromSnapshot(Object? value) {
    if (value is _GuruListData) return value;
    if (value is List<_GuruItem>) {
      return _GuruListData(
        guru: value,
        mapelById: const {},
        kelasById: const {},
      );
    }
    return _GuruListData.empty();
  }

  List<String> mapelNamesFor(_GuruItem item) {
    return item.mapelIds
        .map((id) => mapelById[id] ?? 'ID mapel $id')
        .toList();
  }

  String? kelasAsuhNameFor(_GuruItem item) {
    if (item.kelasAsuhIds.isEmpty) return null;
    final id = item.kelasAsuhIds.first;
    return kelasById[id] ?? 'ID kelas $id';
  }
}

class _GuruItem {
  const _GuruItem({
    required this.id,
    required this.nama,
    required this.email,
    required this.nip,
    List<int>? mapelIds,
    List<int>? kelasAsuhIds,
    this.fotoUrl,
  })  : _mapelIds = mapelIds,
        _kelasAsuhIds = kelasAsuhIds;

  final int id;
  final String nama;
  final String email;
  final String nip;
  final List<int>? _mapelIds;
  final List<int>? _kelasAsuhIds;
  final String? fotoUrl;

  List<int> get mapelIds => _mapelIds ?? const <int>[];
  List<int> get kelasAsuhIds => _kelasAsuhIds ?? const <int>[];

  factory _GuruItem.fromJson(Map<String, dynamic> json) {
    return _GuruItem(
      id: json['id'],
      nama: json['nama'] ?? '',
      email: json['email'] ?? '',
      nip: json['nip'] ?? '',
      mapelIds: _intListFromJson(json, 'mapel_ids', 'mapel_id'),
      kelasAsuhIds: _intListFromJson(json, 'kelas_asuh_ids', 'kelas_asuh_id'),
      fotoUrl: json['foto_url'],
    );
  }
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

Map<int, String> _labelMapFromResponse(List response, String labelKey) {
  final labels = <int, String>{};
  for (final raw in response) {
    final item = raw as Map<String, dynamic>;
    final id = _intFromJson(item['id']);
    if (id != null) {
      labels[id] = item[labelKey]?.toString() ?? '';
    }
  }
  return labels;
}

class _OptionItem {
  const _OptionItem({
    required this.id,
    required this.label,
    this.waliKelasId,
  });

  final int id;
  final String label;
  final int? waliKelasId;

  factory _OptionItem.fromJson(dynamic json, String labelKey) {
    final item = json as Map<String, dynamic>;
    return _OptionItem(
      id: item['id'],
      label: item[labelKey] ?? '',
      waliKelasId: _intFromJson(item['wali_kelas_id']),
    );
  }
}

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

const _fallbackMapelOptions = [
  _OptionItem(id: 1, label: 'Matematika'),
  _OptionItem(id: 2, label: 'Bahasa Indonesia'),
  _OptionItem(id: 3, label: 'IPA'),
];
