import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_alert.dart';

class GuruProfilePage extends StatefulWidget {
  const GuruProfilePage({
    super.key,
    required this.user,
  });

  final User user;

  @override
  State<GuruProfilePage> createState() => _GuruProfilePageState();
}

class _GuruProfilePageState extends State<GuruProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _imagePicker = ImagePicker();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPickingPhoto = false;
  bool _obscurePassword = true;
  String? _fotoUrl;

  @override
  void initState() {
    super.initState();
    _namaController.text = widget.user.nama;
    _emailController.text = widget.user.email;
    _fotoUrl = widget.user.fotoUrl;
    _loadProfile();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _api.get('/api/guru/me');
      if (!mounted) return;
      setState(() {
        _namaController.text = response['nama']?.toString() ?? widget.user.nama;
        _emailController.text =
            response['email']?.toString() ?? widget.user.email;
        _fotoUrl = response['foto_url']?.toString();
      });
    } catch (_) {
      // Data dari login tetap dipakai kalau detail profil gagal dimuat.
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
      final photoData = await _encodePhotoForDatabase(image.path);
      if (!mounted) return;
      setState(() {
        _fotoUrl = photoData;
      });
    } on MissingPluginException {
      _showMessage(
        'Plugin foto belum aktif. Stop aplikasi lalu jalankan ulang dengan flutter run.',
      );
    } on PlatformException catch (error) {
      _showMessage(error.message ?? 'Galeri foto tidak bisa dibuka');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final payload = <String, dynamic>{
      'nama': _namaController.text.trim(),
      'email': _emailController.text.trim(),
      'foto_url': _fotoUrl,
    };

    if (_passwordController.text.trim().isNotEmpty) {
      payload['password'] = _passwordController.text.trim();
    }

    try {
      final response = await _api.put('/api/guru/me', payload);
      if (!mounted) return;

      final responseFotoUrl = response['foto_url']?.toString();
      final updatedUser = widget.user.copyWith(
        nama: response['nama']?.toString() ?? _namaController.text.trim(),
        jenisKelamin: response['jenis_kelamin']?.toString(),
        email: response['email']?.toString() ?? _emailController.text.trim(),
        fotoUrl: responseFotoUrl == null || responseFotoUrl.isEmpty
            ? _fotoUrl
            : responseFotoUrl,
      );

      await AppAlert.success(
        context,
        title: 'Berhasil',
        message: 'Profil guru berhasil diperbarui.',
      );
      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    AppAlert.error(
      context,
      title: 'Terjadi Kesalahan',
      message: message,
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

  Future<String> _encodePhotoForDatabase(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final mimeType = _mimeTypeFromPath(sourcePath);
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _mimeTypeFromPath(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final photoProvider = _photoProvider(_fotoUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: const Text('Profil Guru'),
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
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: const Color(0xFFEFF6FF),
                            backgroundImage: photoProvider,
                            child: photoProvider == null
                                ? Text(
                                    _namaController.text.isEmpty
                                        ? 'G'
                                        : _namaController.text[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              onPressed: _isPickingPhoto ? null : _pickPhoto,
                              icon: _isPickingPhoto
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.photo_camera_rounded),
                              tooltip: 'Pilih foto profil',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _namaController.text.isEmpty
                            ? 'Guru'
                            : _namaController.text,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF191B23),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF737686),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Akun',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF191B23),
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _namaController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDecoration(
                          label: 'Nama Pengguna Guru',
                          icon: Icons.person_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Nama pengguna wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(
                          label: 'Email',
                          icon: Icons.email_rounded,
                        ),
                        onChanged: (_) => setState(() {}),
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
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          label: 'Password Baru',
                          icon: Icons.lock_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                            tooltip: 'Tampilkan password',
                          ),
                        ),
                        validator: (value) {
                          if (value != null &&
                              value.trim().isNotEmpty &&
                              value.trim().length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
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
                    label: Text(_isLoading ? 'Menyimpan' : 'Simpan Profil'),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFC3C6D7).withOpacity(0.5)),
      borderRadius: BorderRadius.circular(16),
    );
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
}
