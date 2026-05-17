import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../ai/face_embedder.dart';
import '../../ai/realtime_face_detector.dart';
import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class AdminSiswaView extends StatefulWidget {
  const AdminSiswaView({super.key});

  @override
  State<AdminSiswaView> createState() => _AdminSiswaViewState();
}

class _AdminSiswaViewState extends State<AdminSiswaView> {
  final ApiService _api = ApiService();
  late Future<Object?> _siswaFuture;

  @override
  void initState() {
    super.initState();
    _siswaFuture = _loadSiswa();
  }

  Future<_SiswaListData> _loadSiswa() async {
    final responses = await Future.wait([
      _api.get('/api/siswa/'),
      _api.get('/api/kelas/'),
    ]);
    return _SiswaListData(
      siswa: (responses[0] as List)
          .map((item) => _SiswaItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      kelasById: _kelasMapFromResponse(responses[1] as List),
    );
  }

  Future<void> _openForm({_SiswaItem? siswa}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TambahSiswaPage(siswa: siswa),
      ),
    );

    if (changed == true && mounted) {
      setState(() {
        _siswaFuture = _loadSiswa();
      });
    }
  }

  Future<void> _deleteSiswa(_SiswaItem siswa) async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Hapus Siswa',
      message:
          'Hapus data ${siswa.nama}? Data embedding wajah dan riwayat presensi siswa ini juga akan dihapus.',
      confirmText: 'Hapus',
    );

    if (!confirmed) return;

    try {
      await _api.delete('/api/siswa/${siswa.id}');
      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Data siswa berhasil dihapus.',
      );
      setState(() {
        _siswaFuture = _loadSiswa();
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
      _siswaFuture = _loadSiswa();
    });
    try {
      await _siswaFuture;
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
                'Data Siswa',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kelola identitas, kelas, dan data wajah siswa',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF434655),
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.person_add_alt_rounded),
                  label: const Text('Tambah Siswa'),
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
                future: _siswaFuture,
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
                        title: 'Data siswa belum bisa dimuat',
                        description: snapshot.error
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      ),
                    );
                  }

                  final data = _SiswaListData.fromSnapshot(snapshot.data);
                  final siswa = data.siswa;
                  if (siswa.isEmpty) {
                    return const _DataPanel(
                      child: _EmptyState(
                        icon: Icons.school_outlined,
                        title: 'Belum ada data siswa',
                        description:
                            'Tambahkan siswa pertama sebelum menjalankan presensi kelas.',
                      ),
                    );
                  }

                  return Column(
                    children: siswa
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SiswaCard(
                              siswa: item,
                              kelasName: data.kelasNameFor(item),
                              onEdit: () => _openForm(siswa: item),
                              onDelete: () => _deleteSiswa(item),
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

class TambahSiswaPage extends StatefulWidget {
  const TambahSiswaPage({
    super.key,
    this.siswa,
  });

  final _SiswaItem? siswa;

  @override
  State<TambahSiswaPage> createState() => _TambahSiswaPageState();
}

class _TambahSiswaPageState extends State<TambahSiswaPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _namaController = TextEditingController();
  final _nisController = TextEditingController();
  final _alamatController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _faceEmbedder = FaceEmbedder();
  final _faceDetector = RealtimeFaceDetector();

  bool _isLoading = false;
  bool _isPickingPhoto = false;
  bool _isPickingEmbeddingPhotos = false;
  String? _selectedFotoPath;
  String? _selectedJenisKelamin;
  final List<String> _embeddingPhotoPaths = [];
  int? _selectedKelasId;
  String _currentEmbeddingStatus = 'belum_diproses';
  List<_OptionItem> _kelasOptions = const [];

  bool get _isEditMode => widget.siswa != null;

  @override
  void initState() {
    super.initState();
    final siswa = widget.siswa;
    if (siswa != null) {
      _namaController.text = siswa.nama;
      _nisController.text = siswa.nis;
      _alamatController.text = siswa.alamat ?? '';
      _selectedFotoPath = siswa.fotoUrl;
      _selectedJenisKelamin = siswa.jenisKelamin;
      _selectedKelasId = siswa.kelasId;
      _currentEmbeddingStatus = siswa.embeddingStatus;
    }
    _loadKelasOptions();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
    _alamatController.dispose();
    _faceEmbedder.close();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _loadKelasOptions() async {
    try {
      final response = await _api.get('/api/kelas/');
      if (!mounted) return;
      setState(() {
        _kelasOptions = (response as List)
            .map((item) => _OptionItem.fromJson(item, 'nama_kelas'))
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal Memuat Kelas',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
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
      _showError('Plugin foto belum aktif. Stop aplikasi lalu jalankan ulang.');
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Galeri foto tidak bisa dibuka');
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _clearPhoto() {
    setState(() {
      _selectedFotoPath = null;
    });
  }

  Future<void> _pickEmbeddingPhotos() async {
    if (_isPickingEmbeddingPhotos) return;
    setState(() => _isPickingEmbeddingPhotos = true);

    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (images.isEmpty || !mounted) return;
      setState(() {
        for (final image in images) {
          if (!_embeddingPhotoPaths.contains(image.path)) {
            _embeddingPhotoPaths.add(image.path);
          }
        }
        _currentEmbeddingStatus = 'belum_diproses';
      });
    } on MissingPluginException {
      _showError('Plugin foto belum aktif. Stop aplikasi lalu jalankan ulang.');
    } on PlatformException catch (error) {
      _showError(error.message ?? 'Galeri foto tidak bisa dibuka');
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isPickingEmbeddingPhotos = false);
    }
  }

  void _removeEmbeddingPhoto(String path) {
    setState(() {
      _embeddingPhotoPaths.remove(path);
    });
  }

  void _clearEmbeddingPhotos() {
    setState(() {
      _embeddingPhotoPaths.clear();
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    AppAlert.error(
      context,
      title: 'Terjadi Kesalahan',
      message: message,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final fotoUrl = await _api.uploadPhotoIfLocal(_selectedFotoPath, 'siswa');
      final payload = <String, dynamic>{
        'nama': _namaController.text.trim(),
        'nis': _nisController.text.trim(),
        'jenis_kelamin': _selectedJenisKelamin,
        'kelas_id': _selectedKelasId,
        'alamat': _alamatController.text.trim().isEmpty
            ? null
            : _alamatController.text.trim(),
        'foto_url': fotoUrl,
        'embedding_status': _initialEmbeddingStatus(),
      };

      final dynamic response;
      if (_isEditMode) {
        response = await _api.put('/api/siswa/${widget.siswa!.id}', payload);
      } else {
        response = await _api.post('/api/siswa/', payload);
      }

      final siswaId = _intFromJson(
            response is Map ? response['id'] : null,
          ) ??
          widget.siswa?.id;
      final embeddingProcessed = await _processAndUploadEmbedding(siswaId);

      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: embeddingProcessed
            ? 'Data siswa dan embedding berhasil disimpan.'
            : _isEditMode
                ? 'Data siswa berhasil diperbarui.'
                : 'Data siswa berhasil ditambahkan.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _processAndUploadEmbedding(int? siswaId) async {
    if (siswaId == null || _embeddingPhotoPaths.isEmpty) {
      return false;
    }

    try {
      for (final fotoPath in _embeddingPhotoPaths) {
        if (fotoPath.startsWith('http://') || fotoPath.startsWith('https://')) {
          continue;
        }
        final embedding = await _createEmbeddingFromDetectedFace(fotoPath);
        await _api.post('/api/embedding/', {
          'siswa_id': siswaId,
          'embedding': embedding,
        });
      }
      await _api.put('/api/siswa/$siswaId', {
        'embedding_status': 'diproses',
      });
      return true;
    } catch (error) {
      await _api.put('/api/siswa/$siswaId', {
        'embedding_status': 'gagal',
      });
      throw Exception('Data siswa tersimpan, tetapi embedding gagal: $error');
    }
  }

  Future<List<double>> _createEmbeddingFromDetectedFace(String fotoPath) async {
    final bytes = await File(fotoPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Foto embedding tidak bisa dibaca');
    }

    await _faceDetector.load();
    final faces = await _faceDetector.detectImage(img.bakeOrientation(decoded));
    if (faces.isEmpty) {
      throw Exception(
        'Tidak ada wajah terdeteksi pada salah satu foto embedding',
      );
    }

    final bestFace = faces.reduce((best, item) {
      final bestArea = best.width * best.height;
      final itemArea = item.width * item.height;
      return itemArea > bestArea ? item : best;
    });
    final faceImage = bestFace.faceImage;
    if (faceImage == null) {
      throw Exception('Crop wajah dari foto embedding gagal');
    }

    return _faceEmbedder.embedImage(faceImage);
  }

  String _initialEmbeddingStatus() {
    if (_embeddingPhotoPaths.isNotEmpty) return 'belum_diproses';
    if (_isEditMode) return _currentEmbeddingStatus;
    return 'belum_diproses';
  }

  @override
  Widget build(BuildContext context) {
    final kelasDropdownValue = _kelasOptions.any(
      (item) => item.id == _selectedKelasId,
    )
        ? _selectedKelasId
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Data Siswa' : 'Tambah Data Siswa'),
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
                  title: 'Identitas Siswa',
                  children: [
                    _TextField(
                      controller: _namaController,
                      label: 'Nama Siswa',
                      icon: Icons.person_rounded,
                      onChanged: (_) => setState(() {}),
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 14),
                    _TextField(
                      controller: _nisController,
                      label: 'NIS',
                      icon: Icons.badge_rounded,
                      keyboardType: TextInputType.number,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _selectedJenisKelamin,
                      decoration: _inputDecoration(
                        label: 'Jenis Kelamin',
                        icon: Icons.wc_rounded,
                      ),
                      items: _genderOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedJenisKelamin = value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Jenis kelamin wajib dipilih';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      value: kelasDropdownValue,
                      decoration: _inputDecoration(
                        label: 'Kelas',
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
                    _TextField(
                      controller: _alamatController,
                      label: 'Alamat',
                      icon: Icons.home_rounded,
                      keyboardType: TextInputType.streetAddress,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Data Wajah',
                  children: [
                    _EmbeddingStatusInfo(
                      status: _embeddingPhotoPaths.isNotEmpty
                          ? 'belum_diproses'
                          : _currentEmbeddingStatus,
                    ),
                    const SizedBox(height: 14),
                    _EmbeddingPhotosPicker(
                      photoPaths: _embeddingPhotoPaths,
                      isPicking: _isPickingEmbeddingPhotos,
                      onPickPhotos: _pickEmbeddingPhotos,
                      onRemovePhoto: _removeEmbeddingPhoto,
                      onClearPhotos: _clearEmbeddingPhotos,
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
                              : 'Simpan Siswa',
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
    final initial = name.isEmpty ? 'S' : name[0].toUpperCase();
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
            'Foto Profil Siswa',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF191B23),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            photoPath == null
                ? 'Pilih foto dari galeri HP'
                : 'Foto profil lokal sudah dipilih',
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

class _EmbeddingStatusInfo extends StatelessWidget {
  const _EmbeddingStatusInfo({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.face_retouching_natural_rounded,
            color: Color(0xFF737686),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Embedding',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF737686),
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  _embeddingLabel(status),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF191B23),
                      ),
                ),
              ],
            ),
          ),
          const Text(
            'Otomatis',
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddingPhotosPicker extends StatelessWidget {
  const _EmbeddingPhotosPicker({
    required this.photoPaths,
    required this.isPicking,
    required this.onPickPhotos,
    required this.onRemovePhoto,
    required this.onClearPhotos,
  });

  final List<String> photoPaths;
  final bool isPicking;
  final VoidCallback onPickPhotos;
  final ValueChanged<String> onRemovePhoto;
  final VoidCallback onClearPhotos;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF737686),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto untuk Embedding',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF191B23),
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pilih beberapa foto wajah siswa untuk data pengenalan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF737686),
                          ),
                    ),
                  ],
                ),
              ),
              if (photoPaths.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${photoPaths.length} foto',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isPicking ? null : onPickPhotos,
              icon: isPicking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded),
              label: Text(isPicking ? 'Membuka Galeri' : 'Tambah Foto Embedding'),
            ),
          ),
          if (photoPaths.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Belum ada foto embedding yang dipilih',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF737686),
                  ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            GridView.builder(
              itemCount: photoPaths.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final path = photoPaths[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => onRemovePhoto(path),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClearPhotos,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Hapus semua'),
              ),
            ),
          ],
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
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: _inputDecoration(label: label, icon: icon),
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

ImageProvider? _photoProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  if (path.startsWith('/uploads/')) {
    return NetworkImage(ApiService.resolveMediaUrl(path));
  }
  if (!File(path).existsSync()) return null;
  return FileImage(File(path));
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

class _SiswaCard extends StatefulWidget {
  const _SiswaCard({
    required this.siswa,
    required this.kelasName,
    required this.onEdit,
    required this.onDelete,
  });

  final _SiswaItem siswa;
  final String kelasName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SiswaCard> createState() => _SiswaCardState();
}

class _SiswaCardState extends State<_SiswaCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final siswa = widget.siswa;
    final photoProvider = _photoProvider(siswa.fotoUrl);

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
                              siswa.nama.isEmpty
                                  ? 'S'
                                  : siswa.nama[0].toUpperCase(),
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
                            siswa.nama,
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
                            widget.kelasName,
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
                                label: siswa.nis,
                                maxWidth: 118,
                              ),
                              _TinyMeta(
                                icon: Icons.wc_rounded,
                                label: _genderLabel(siswa.jenisKelamin),
                                maxWidth: 112,
                              ),
                              _TinyMeta(
                                icon: Icons.face_retouching_natural_rounded,
                                label: _embeddingLabel(siswa.embeddingStatus),
                                maxWidth: 128,
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
                            tooltip: 'Edit siswa',
                            onPressed: widget.onEdit,
                          ),
                          const SizedBox(height: 6),
                          _MinimalIconButton(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFDC2626),
                            tooltip: 'Hapus siswa',
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
                  secondChild: _SiswaDetails(
                    siswa: siswa,
                    kelasName: widget.kelasName,
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

class _SiswaDetails extends StatelessWidget {
  const _SiswaDetails({
    required this.siswa,
    required this.kelasName,
  });

  final _SiswaItem siswa;
  final String kelasName;

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
          children: [
            _DetailLine(
              icon: Icons.class_rounded,
              title: 'Kelas',
              value: kelasName,
            ),
            const SizedBox(height: 12),
            _DetailLine(
              icon: Icons.wc_rounded,
              title: 'Jenis kelamin',
              value: _genderLabel(siswa.jenisKelamin),
            ),
            const SizedBox(height: 12),
            _DetailLine(
              icon: Icons.home_rounded,
              title: 'Alamat',
              value: (siswa.alamat == null || siswa.alamat!.trim().isEmpty)
                  ? 'Alamat belum diisi'
                  : siswa.alamat!,
            ),
            const SizedBox(height: 12),
            _DetailLine(
              icon: Icons.face_retouching_natural_rounded,
              title: 'Status embedding',
              value: _embeddingLabel(siswa.embeddingStatus),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

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
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SiswaItem {
  const _SiswaItem({
    required this.id,
    required this.nama,
    required this.nis,
    required this.kelasId,
    required this.embeddingStatus,
    this.jenisKelamin,
    this.alamat,
    this.fotoUrl,
  });

  final int id;
  final String nama;
  final String nis;
  final int kelasId;
  final String embeddingStatus;
  final String? jenisKelamin;
  final String? alamat;
  final String? fotoUrl;

  factory _SiswaItem.fromJson(Map<String, dynamic> json) {
    return _SiswaItem(
      id: json['id'],
      nama: json['nama'] ?? '',
      nis: json['nis'] ?? '',
      kelasId: _intFromJson(json['kelas_id']) ?? 0,
      jenisKelamin: _normalizeGender(json['jenis_kelamin']),
      alamat: json['alamat'],
      fotoUrl: json['foto_url'],
      embeddingStatus: json['embedding_status'] ?? 'belum_diproses',
    );
  }
}

class _SiswaListData {
  const _SiswaListData({
    required this.siswa,
    required this.kelasById,
  });

  final List<_SiswaItem> siswa;
  final Map<int, String> kelasById;

  factory _SiswaListData.empty() {
    return const _SiswaListData(siswa: [], kelasById: {});
  }

  factory _SiswaListData.fromSnapshot(Object? value) {
    if (value is _SiswaListData) return value;
    if (value is List<_SiswaItem>) {
      return _SiswaListData(siswa: value, kelasById: const {});
    }
    return _SiswaListData.empty();
  }

  String kelasNameFor(_SiswaItem item) {
    return kelasById[item.kelasId] ?? 'Kelas belum diketahui';
  }
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

Map<int, String> _kelasMapFromResponse(List response) {
  final labels = <int, String>{};
  for (final raw in response) {
    final item = raw as Map<String, dynamic>;
    final id = _intFromJson(item['id']);
    if (id != null) {
      labels[id] = item['nama_kelas']?.toString() ?? '';
    }
  }
  return labels;
}

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

const _genderOptions = ['Laki-laki', 'Perempuan'];

String _genderLabel(String? value) {
  if (value == null || value.trim().isEmpty) return 'Belum diisi';
  return value;
}

String? _normalizeGender(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return _genderOptions.contains(text) ? text : null;
}

String _embeddingLabel(String value) {
  switch (value) {
    case 'diproses':
      return 'Diproses';
    case 'gagal':
      return 'Gagal';
    default:
      return 'Belum diproses';
  }
}
