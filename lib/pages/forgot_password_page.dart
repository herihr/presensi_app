import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../utils/app_alert.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.initialEmail,
    required this.initialRole,
  });

  final String initialEmail;
  final String initialRole;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authController = AuthController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late String _role;
  bool _codeSent = false;
  bool _isLoading = false;
  bool _emailSentByServer = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final emailSent = await _authController.requestPasswordReset(
        _emailController.text.trim(),
        _role,
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _emailSentByServer = emailSent;
        _isLoading = false;
      });
      await AppAlert.success(
        context,
        title: 'Kode Dibuat',
        message: emailSent
            ? 'Kode reset password sudah dikirim ke email kamu.'
            : 'Kode reset sudah dibuat, tetapi SMTP belum dikonfigurasi. Cek terminal backend untuk kode reset sementara.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await AppAlert.error(
        context,
        title: 'Gagal Mengirim Kode',
        message: _resetErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authController.resetPassword(
        email: _emailController.text.trim(),
        role: _role,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      await AppAlert.success(
        context,
        title: 'Password Diubah',
        message: 'Silakan login menggunakan password baru.',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await AppAlert.error(
        context,
        title: 'Reset Gagal',
        message: _resetErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _resetErrorMessage(Object error) {
    final message = error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
    final lower = message.toLowerCase();

    if (lower.contains('http 404') &&
        lower.contains('not found') &&
        !lower.contains('email tidak ditemukan')) {
      return 'Endpoint reset password belum terbaca oleh server. Restart uvicorn lalu coba lagi.';
    }
    if (lower.contains('404') || lower.contains('email tidak ditemukan')) {
      return 'Email tidak ditemukan untuk role yang dipilih.';
    }
    if (lower.contains('kode reset tidak valid')) {
      return 'Kode reset salah. Periksa kembali kode dari email.';
    }
    if (lower.contains('kedaluwarsa')) {
      return 'Kode reset sudah kedaluwarsa. Minta kode baru.';
    }
    if (lower.contains('minimal 6')) {
      return 'Password baru minimal 6 karakter.';
    }
    if (lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('network')) {
      return 'Server tidak bisa dijangkau. Periksa koneksi dan alamat server.';
    }

    return message.isEmpty ? 'Permintaan belum bisa diproses.' : message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8FF),
        elevation: 0,
        foregroundColor: const Color(0xFF191B23),
        title: const Text('Lupa Password'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFF2563EB),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Reset password akun',
                style: TextStyle(
                  color: Color(0xFF191B23),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Masukkan kode reset dan password baru.'
                    : 'Pilih role dan masukkan email akun. Kode reset akan dikirim ke email tersebut.',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              _RoleSelector(
                selectedRole: _role,
                enabled: !_codeSent && !_isLoading,
                onChanged: (role) => setState(() => _role = role),
              ),
              const SizedBox(height: 18),
              Form(
                key: _emailFormKey,
                child: _ResetTextField(
                  controller: _emailController,
                  label: 'Email',
                  hintText: 'nama@email.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_codeSent && !_isLoading,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Email wajib diisi';
                    if (!text.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _codeSent ? _buildResetForm() : const SizedBox.shrink(),
              ),
              if (_codeSent && !_emailSentByServer) ...[
                const SizedBox(height: 16),
                const _InfoBox(
                  message:
                      'SMTP backend belum aktif, jadi email belum benar-benar terkirim. Untuk uji lokal, lihat kode reset di terminal uvicorn.',
                ),
              ],
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading
                      ? null
                      : _codeSent
                          ? _resetPassword
                          : _requestCode,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_codeSent
                          ? Icons.save_rounded
                          : Icons.mark_email_read_rounded),
                  label: Text(
                    _isLoading
                        ? 'Memproses'
                        : _codeSent
                            ? 'Simpan Password Baru'
                            : 'Kirim Kode Reset',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _codeSent = false;
                              _codeController.clear();
                              _passwordController.clear();
                              _confirmPasswordController.clear();
                            });
                          },
                    child: const Text('Ubah email atau kirim ulang kode'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResetForm() {
    return Form(
      key: _resetFormKey,
      child: Column(
        children: [
          _ResetTextField(
            controller: _codeController,
            label: 'Kode Reset',
            hintText: '6 digit kode',
            icon: Icons.pin_rounded,
            keyboardType: TextInputType.number,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Kode reset wajib diisi';
              if (text.length != 6) return 'Kode reset harus 6 digit';
              return null;
            },
          ),
          const SizedBox(height: 18),
          _ResetTextField(
            controller: _passwordController,
            label: 'Password Baru',
            hintText: 'Minimal 6 karakter',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            validator: (value) {
              if ((value ?? '').length < 6) {
                return 'Password baru minimal 6 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _ResetTextField(
            controller: _confirmPasswordController,
            label: 'Konfirmasi Password',
            hintText: 'Ulangi password baru',
            icon: Icons.verified_user_outlined,
            obscureText: _obscurePassword,
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Konfirmasi password tidak sama';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.onChanged,
  });

  final String selectedRole;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _RoleOption(
            label: 'Guru',
            value: 'guru',
            selectedRole: selectedRole,
            enabled: enabled,
            onChanged: onChanged,
          ),
          _RoleOption(
            label: 'Admin',
            value: 'admin',
            selectedRole: selectedRole,
            enabled: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.value,
    required this.selectedRole,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String selectedRole;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedRole == value;
    return Expanded(
      child: InkWell(
        onTap: enabled ? () => onChanged(value) : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x140B3558),
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: !enabled
                  ? const Color(0xFF94A3B8)
                  : selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetTextField extends StatelessWidget {
  const _ResetTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8DCE8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD8DCE8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF92400E),
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
