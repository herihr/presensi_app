import 'dart:ui';

import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../utils/app_alert.dart';
import 'admin/admin_page.dart';
import 'forgot_password_page.dart';
import 'guru/guru_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = AuthController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String _selectedRole = 'guru';

  @override
  void initState() {
    super.initState();
    _emailController.text = 'guru@gmail.com';
    _passwordController.text = '123456';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _authController.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted || user == null) return;

      // Route based on user role
      if (user.isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminPage(user: user),
          ),
        );
      } else if (user.isGuru) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GuruPage(user: user),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: _loginErrorTitle(error),
        message: _loginErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _loginErrorTitle(Object error) {
    final message = _normalizeErrorMessage(error);
    if (_isCredentialError(message)) return 'Login Gagal';
    if (_isConnectionError(message)) return 'Koneksi Bermasalah';
    return 'Login Belum Berhasil';
  }

  String _loginErrorMessage(Object error) {
    final message = _normalizeErrorMessage(error);

    if (_isCredentialError(message)) {
      return 'Username/email atau password salah. Silakan periksa kembali data login kamu.';
    }

    if (_isConnectionError(message)) {
      return 'Login gagal karena perangkat sedang offline atau server tidak bisa dijangkau. Periksa koneksi internet dan alamat server.';
    }

    if (message.contains('internal server error') ||
        message.contains('response login tidak valid')) {
      return 'Server sedang bermasalah. Silakan coba beberapa saat lagi.';
    }

    return 'Login belum bisa diproses. Silakan coba lagi.';
  }

  bool _isCredentialError(String message) {
    return message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('invalid credentials') ||
        message.contains('invalid username') ||
        message.contains('invalid email') ||
        message.contains('invalid password') ||
        message.contains('invalid') ||
        message.contains('incorrect') ||
        message.contains('wrong') ||
        message.contains('login gagal') ||
        message.contains('not found') ||
        message.contains('tidak ditemukan') ||
        message.contains('salah') ||
        message.contains('password');
  }

  bool _isConnectionError(String message) {
    return message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('xmlhttprequest error') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed') ||
        message.contains('connection') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('failed host lookup') ||
        message.contains('no address associated') ||
        message.contains('network is unreachable') ||
        message.contains('network');
  }

  String _normalizeErrorMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim()
        .toLowerCase();
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _emailController.text = role == 'admin' ? 'admin@gmail.com' : 'guru@gmail.com';
    });
  }

  Future<void> _openForgotPassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(
          initialEmail: _emailController.text.trim(),
          initialRole: _selectedRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 330,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.18,
                      child: Center(
                        child: Container(
                          width: 500,
                          height: 500,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade400,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade400,
                                blurRadius: 100,
                                spreadRadius: 50,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: SizedBox(
                      width: 196,
                      height: 196,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, 14),
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 12,
                                sigmaY: 12,
                              ),
                              child: Opacity(
                                opacity: 0.32,
                                child: ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Image.asset(
                                      'lib/assets/img/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(22),
                            child: Image.asset(
                              'lib/assets/img/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Section: Login Card
            Transform.translate(
              offset: const Offset(0, -40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      // Header
                      Column(
                        children: [
                          Text(
                            'Masuk',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 32,
                                  color: const Color(0xFF191B23),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Masuk untuk mengelola presensi sekolah',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF434655),
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Role Toggle
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _RoleToggleButton(
                              label: 'GURU',
                              isSelected: _selectedRole == 'guru',
                              onTap: () => _selectRole('guru'),
                            ),
                            _RoleToggleButton(
                              label: 'ADMIN',
                              isSelected: _selectedRole == 'admin',
                              onTap: () => _selectRole('admin'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                                  child: Text(
                                    'ALAMAT EMAIL',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: const Color(0xFF434655),
                                        ),
                                  ),
                                ),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'name@school.edu',
                                    prefixIcon: const Icon(
                                      Icons.mail_outlined,
                                      color: Color(0xFF737686),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFFFFFFF),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFC3C6D7),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
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
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Password Field
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'KATA SANDI',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                              color: const Color(0xFF434655),
                                            ),
                                      ),
                                      GestureDetector(
                                        onTap: _openForgotPassword,
                                        child: Text(
                                          'LUPA?',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                                color: const Color(0xFF2563EB),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      color: Color(0xFF737686),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: const Color(0xFF737686),
                                      ),
                                      onPressed: () {
                                        setState(() => _obscurePassword = !_obscurePassword);
                                      },
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFFFFFFF),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFC3C6D7),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password wajib diisi';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Login Button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading ? null : _login,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward),
                                label: Text(
                                  _isLoading ? 'Memproses' : 'Masuk',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleToggleButton extends StatelessWidget {
  const _RoleToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF434655),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
