import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../models/auth/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_alert.dart';
import '../login_page.dart';
import 'admin_dashboard_view.dart';
import 'admin_guru_view.dart';
import 'admin_siswa_view.dart';
import 'admin_kelas_view.dart';
import 'admin_mata_pelajaran_view.dart';
import 'admin_jadwal_view.dart';
import 'admin_profile_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({
    super.key,
    this.user,
  });

  final User? user;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedNavIndex = 0;
  User? _user;

  User get _currentUser {
    return _user ??
        widget.user ??
        User(
          id: 0,
          nama: 'Admin',
          email: '',
          role: 'admin',
          isWali: false,
          isMapel: false,
          accessToken: '',
          tokenType: 'bearer',
        );
  }

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _openProfile() async {
    final currentUser = _currentUser;
    if (currentUser.id == 0) {
      await AppAlert.warning(
        context,
        title: 'Sesi Tidak Valid',
        message: 'Silakan login ulang untuk membuka profil admin.',
      );
      return;
    }

    final updatedUser = await Navigator.of(context).push<User>(
      MaterialPageRoute(
        builder: (_) => AdminProfilePage(user: currentUser),
      ),
    );

    if (updatedUser == null || !mounted) return;
    setState(() {
      _user = updatedUser;
    });
  }

  ImageProvider? _profileImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('data:image/')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex == -1) return null;
      return MemoryImage(base64Decode(path.substring(commaIndex + 1)));
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    if (path.startsWith('/uploads/')) {
      return NetworkImage(ApiService.resolveMediaUrl(path));
    }
    if (!File(path).existsSync()) return null;
    return FileImage(File(path));
  }

  Future<void> _logout() async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Keluar',
      message: 'Keluar dari akun admin?',
      confirmText: 'Keluar',
    );

    if (!confirmed || !mounted) return;
    ApiService.clearToken();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _currentUser;
    final profileImage = _profileImageProvider(currentUser.fotoUrl);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      // ============ HEADER (FIX) ============
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 1,
        titleSpacing: 16,
        title: Tooltip(
          message: 'Profil admin',
          child: InkWell(
            onTap: _openProfile,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: profileImage,
                    child: profileImage == null
                        ? Text(
                            currentUser.nama.isEmpty
                                ? 'A'
                                : currentUser.nama[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      currentUser.nama.isEmpty ? 'PresenSatu' : currentUser.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            tooltip: 'Keluar',
            onPressed: _logout,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF737686)),
            onPressed: () {},
          ),
        ],
        centerTitle: false,
      ),
      // ============ BODY (DYNAMIC) ============
      body: _buildContent(),
      // ============ FOOTER (FIX) ============
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedNavIndex,
          onTap: (index) {
            setState(() => _selectedNavIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: const Color(0xFF737686),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Dasbor',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Guru',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school_outlined),
              label: 'Siswa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.class_outlined),
              label: 'Kelas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Mapel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.schedule_outlined),
              label: 'Jadwal',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedNavIndex) {
      case 0:
        return const AdminDashboardView();
      case 1:
        return const AdminGuruView();
      case 2:
        return const AdminSiswaView();
      case 3:
        return const AdminKelasView();
      case 4:
        return const AdminMataPelajaranView();
      case 5:
        return const AdminJadwalView();
      default:
        return const AdminDashboardView();
    }
  }
}
