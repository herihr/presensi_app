import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/auth/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_alert.dart';
import '../login_page.dart';
import 'guru_profile_page.dart';
import 'presensi_page.dart';

part '../../models/guru/guru_recap_model.dart';
part '../../models/guru/guru_schedule_model.dart';
part '../../models/guru/report_model.dart';
part '../../services/guru/guru_recap_service.dart';
part '../../services/guru/guru_schedule_service.dart';
part '../../services/guru/report_export_service.dart';
part '../../widgets/guru/guru_attendance_summary.dart';
part '../../widgets/guru/guru_bottom_nav.dart';
part '../../widgets/guru/guru_header.dart';
part '../../widgets/guru/guru_recap_table.dart';
part '../../widgets/guru/guru_report_download_card.dart';
part '../../widgets/guru/guru_schedule_card.dart';
part 'guru_home_view.dart';
part 'guru_rekap_view.dart';

class GuruPage extends StatefulWidget {
  const GuruPage({
    super.key,
    required this.user,
  });

  final User user;

  @override
  State<GuruPage> createState() => _GuruPageState();
}

class _GuruPageState extends State<GuruPage> {
  int _selectedIndex = 0;
  User? _user;
  late Future<List<_GuruSchedule>> _schedulesFuture;
  late Future<_RecapData> _homeRecapFuture;
  int _recapRefreshKey = 0;

  User get _currentUser => _user ?? widget.user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _schedulesFuture = _loadSchedules();
    _homeRecapFuture = _loadRecapData(_currentUser);
  }

  Future<void> _openPresensi([_GuruSchedule? schedule]) async {
    final selectedSchedule = schedule ?? await _firstAvailableSchedule();
    if (selectedSchedule == null) {
      if (!mounted) return;
      await AppAlert.warning(
        context,
        title: 'Belum Ada Jadwal',
        message: 'Belum ada jadwal mengajar yang bisa dipakai untuk presensi.',
      );
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PresensiPage(
          mapel: selectedSchedule.subject,
          className: selectedSchedule.className,
          jadwalId: selectedSchedule.id,
          kelasId: selectedSchedule.kelasId,
          guruId: _currentUser.id,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _recapRefreshKey++;
      _homeRecapFuture = _loadRecapData(_currentUser);
      if (result == presensiPageResultRekap) {
        _selectedIndex = 1;
      }
    });
  }

  Future<List<_GuruSchedule>> _loadSchedules() async {
    return _loadGuruSchedules(_currentUser);
  }

  Future<_GuruSchedule?> _firstAvailableSchedule() async {
    try {
      final schedules = await _schedulesFuture;
      if (schedules.isEmpty) return null;
      return schedules.first;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openProfile() async {
    final updatedUser = await Navigator.of(context).push<User>(
      MaterialPageRoute(
        builder: (_) => GuruProfilePage(user: _currentUser),
      ),
    );

    if (updatedUser == null || !mounted) return;
    setState(() {
      _user = updatedUser;
    });
  }

  Future<void> _logout() async {
    final confirmed = await AppAlert.confirm(
      context: context,
      title: 'Keluar',
      message: 'Keluar dari akun guru?',
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
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _GuruHomeView(
              user: currentUser,
              profileImage: profileImage,
              schedulesFuture: _schedulesFuture,
              recapFuture: _homeRecapFuture,
              onOpenPresensi: (schedule) => _openPresensi(schedule),
              onOpenProfile: _openProfile,
              onLogout: _logout,
            ),
            _GuruStatsView(
              user: currentUser,
              refreshKey: _recapRefreshKey,
              onOpenProfile: _openProfile,
              onLogout: _logout,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x100B3558),
                blurRadius: 20,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GuruNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Beranda',
                isSelected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _GuruNavItem(
                icon: Icons.insert_chart_outlined_rounded,
                label: 'Rekap',
                isSelected: _selectedIndex == 1,
                onTap: () {
                  setState(() {
                    _selectedIndex = 1;
                    _recapRefreshKey++;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D0B3558),
        blurRadius: 22,
        offset: Offset(0, 8),
      ),
    ],
  );
}
