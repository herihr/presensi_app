import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../utils/app_alert.dart';
import '../login_page.dart';
import 'guru_profile_page.dart';
import 'presensi_page.dart';

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

  User get _currentUser => _user ?? widget.user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _openPresensi([_GuruSchedule? schedule]) {
    final selectedSchedule = schedule ?? _todaySchedules.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresensiPage(
          mapel: selectedSchedule.subject,
          className: selectedSchedule.className,
          jadwalId: selectedSchedule.id,
          guruId: _currentUser.id,
        ),
      ),
    );
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
    if (!File(path).existsSync()) return null;
    return FileImage(File(path));
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
              onOpenPresensi: (schedule) => _openPresensi(schedule),
              onOpenProfile: _openProfile,
              onLogout: _logout,
            ),
            _PlaceholderView(
              icon: Icons.center_focus_strong_rounded,
              title: 'Pindai',
              description: 'Mulai presensi wajah dari jadwal yang sedang aktif.',
              buttonLabel: 'Mulai Pindai Sekarang',
              onPressed: () => _openPresensi(),
            ),
            const _PlaceholderView(
              icon: Icons.groups_rounded,
              title: 'Siswa',
              description: 'Daftar siswa untuk kelas yang diajar akan ditampilkan di sini.',
            ),
            const _GuruStatsView(),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GuruNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Beranda',
                isSelected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
              ),
              _GuruNavItem(
                icon: Icons.center_focus_strong_rounded,
                label: 'Pindai',
                isSelected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _GuruNavItem(
                icon: Icons.groups_rounded,
                label: 'Siswa',
                isSelected: _selectedIndex == 2,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
              _GuruNavItem(
                icon: Icons.insert_chart_outlined_rounded,
                label: 'Rekap',
                isSelected: _selectedIndex == 3,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuruHomeView extends StatelessWidget {
  const _GuruHomeView({
    required this.user,
    required this.profileImage,
    required this.onOpenPresensi,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final User user;
  final ImageProvider? profileImage;
  final ValueChanged<_GuruSchedule?> onOpenPresensi;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final firstName = _firstName(user.nama);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GuruHeader(
            name: firstName,
            profileImage: profileImage,
            onProfileTap: onOpenProfile,
            onLogout: onLogout,
          ),
          const SizedBox(height: 26),
          _SectionHeader(
            title: 'Ringkasan Kehadiran',
            actionText: 'MINGGU INI',
            onTap: () {},
          ),
          const SizedBox(height: 18),
          const _AttendanceSummary(),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Jadwal Hari Ini',
            actionText: 'LIHAT SEMUA  ->',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          ..._todaySchedules.map(
            (schedule) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _ScheduleCard(
                schedule: schedule,
                onTap: () => onOpenPresensi(schedule),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Guru';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }
}

class _GuruHeader extends StatelessWidget {
  const _GuruHeader({
    required this.name,
    required this.profileImage,
    required this.onProfileTap,
    required this.onLogout,
  });

  final String name;
  final ImageProvider? profileImage;
  final VoidCallback onProfileTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Profil guru',
          child: InkWell(
            onTap: onProfileTap,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 29,
              backgroundColor: const Color(0xFFEFF6FF),
              backgroundImage: profileImage,
              child: profileImage == null
                  ? const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF2563EB),
                      size: 32,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELAMAT DATANG',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF65748B),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                'Halo, Pak $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          color: const Color(0xFFDC2626),
          iconSize: 28,
          tooltip: 'Keluar',
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onTap,
  });

  final String title;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF191B23),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1D4ED8),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            actionText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  const _AttendanceSummary();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PercentCard(percentage: 85),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: const [
              _CountCard(
                icon: Icons.check_circle_outline_rounded,
                iconColor: Color(0xFF10B981),
                iconBackground: Color(0xFFE9FFF5),
                value: '342',
                label: 'HADIR',
                valueColor: Color(0xFF009D72),
              ),
              SizedBox(height: 18),
              _CountCard(
                icon: Icons.cancel_outlined,
                iconColor: Color(0xFFCC0000),
                iconBackground: Color(0xFFFFF1F2),
                value: '12',
                label: 'TIDAK HADIR',
                valueColor: Color(0xFFCC0000),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PercentCard extends StatelessWidget {
  const _PercentCard({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 236,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: _softCardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 126),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      strokeWidth: 9,
                      backgroundColor: const Color(0xFFEAF0F9),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFF2563EB)),
                      strokeCap: StrokeCap.square,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'PERSENTASE TOTAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 109,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 12),
      decoration: _softCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.onTap,
  });

  final _GuruSchedule schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: _softCardDecoration(),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      schedule.icon,
                      color: const Color(0xFF2563EB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF191B23),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          schedule.room,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(status: schedule.status),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF0F3F8), height: 1),
              const SizedBox(height: 19),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    schedule.timeRange,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.groups_2_outlined,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    schedule.className,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _ScheduleStatus status;

  @override
  Widget build(BuildContext context) {
    final isOngoing = status == _ScheduleStatus.ongoing;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
      decoration: BoxDecoration(
        color: isOngoing ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        isOngoing ? 'BERLANGSUNG' : 'AKAN DATANG',
        style: TextStyle(
          color: isOngoing ? Colors.white : const Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _GuruNavItem extends StatelessWidget {
  const _GuruNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 76,
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color:
                    isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                size: 26,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuruStatsView extends StatelessWidget {
  const _GuruStatsView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatsTopBar(),
          const SizedBox(height: 30),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rekap Harian',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: const Color(0xFF191B23),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pemantauan Kelas 10-B',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF737686),
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_month_rounded, size: 22),
                label: const Text('9 MEI 2026'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(
                child: _RecapMetricCard(
                  label: 'HADIR',
                  value: '28',
                  valueColor: Color(0xFF004AD8),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _RecapMetricCard(
                  label: 'TIDAK HADIR',
                  value: '04',
                  valueColor: Color(0xFFB80F0F),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _RecapMetricCard(
                  label: 'TERLAMBAT',
                  value: '02',
                  valueColor: Color(0xFF943700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const _StudentLogsCard(),
          const SizedBox(height: 28),
          const _ExportReportCard(),
        ],
      ),
    );
  }
}

class _StatsTopBar extends StatelessWidget {
  const _StatsTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: const Color(0xFFEFF6FF),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF2563EB),
            size: 30,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'PresenSatu',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
          color: const Color(0xFF64748B),
          iconSize: 30,
        ),
      ],
    );
  }
}

class _RecapMetricCard extends StatelessWidget {
  const _RecapMetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC3C6D7), width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF737686),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentLogsCard extends StatelessWidget {
  const _StudentLogsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0B3558),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Log Siswa',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF191B23),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const _LegendDot(color: Color(0xFF10B981), label: 'Hadir'),
                  const SizedBox(width: 10),
                  const _LegendDot(color: Color(0xFFCC0000), label: 'Tidak Hadir'),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: [
                  Container(
                    height: 62,
                    color: const Color(0xFFF3F3FE),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 230,
                          child: Padding(
                            padding: EdgeInsets.only(left: 24),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'SISWA',
                                style: TextStyle(
                                  color: Color(0xFF737686),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...List.generate(
                          6,
                          (index) => SizedBox(
                            width: 66,
                            child: Center(
                              child: Text(
                                'J${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF737686),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._recapRows.map((row) => _StudentLogRow(row: row)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF737686),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StudentLogRow extends StatelessWidget {
  const _StudentLogRow({required this.row});

  final _RecapRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F3F8)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: row.avatarColor,
                    child: Text(
                      row.initials,
                      style: TextStyle(
                        color: row.initialColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...row.logs.map(
            (present) => SizedBox(
              width: 66,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: present ? const Color(0xFF10B981) : const Color(0xFFCC0000),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (present
                                ? const Color(0xFF10B981)
                                : const Color(0xFFCC0000))
                            .withOpacity(0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportReportCard extends StatelessWidget {
  const _ExportReportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302563EB),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan Bulanan Siap',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data agregat bulan Mei sudah tersedia.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.86),
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 130,
            height: 76,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text(
                'Ekspor\nPDF',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  const _PlaceholderView({
    required this.icon,
    required this.title,
    required this.description,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: _softCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: const Color(0xFF2563EB)),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF191B23),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
              ),
              if (buttonLabel != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.center_focus_strong_rounded),
                  label: Text(buttonLabel!),
                ),
              ],
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

class _RecapRow {
  const _RecapRow({
    required this.initials,
    required this.name,
    required this.avatarColor,
    required this.initialColor,
    required this.logs,
  });

  final String initials;
  final String name;
  final Color avatarColor;
  final Color initialColor;
  final List<bool> logs;
}

class _GuruSchedule {
  const _GuruSchedule({
    required this.id,
    required this.subject,
    required this.room,
    required this.timeRange,
    required this.className,
    required this.icon,
    required this.status,
  });

  final int id;
  final String subject;
  final String room;
  final String timeRange;
  final String className;
  final IconData icon;
  final _ScheduleStatus status;
}

enum _ScheduleStatus { ongoing, upcoming }

const _todaySchedules = [
  _GuruSchedule(
    id: 1,
    subject: 'Matematika',
    room: 'Ruang Lab A',
    timeRange: '08:00 - 09:30',
    className: 'Kelas 12-A',
    icon: Icons.menu_book_rounded,
    status: _ScheduleStatus.ongoing,
  ),
  _GuruSchedule(
    id: 2,
    subject: 'Fisika Terapan',
    room: 'Gedung Utama',
    timeRange: '10:00 - 11:30',
    className: 'Kelas 11-B',
    icon: Icons.science_outlined,
    status: _ScheduleStatus.upcoming,
  ),
];

const _recapRows = [
  _RecapRow(
    initials: 'AS',
    name: 'Andi Saputra',
    avatarColor: Color(0xFFDCEBFF),
    initialColor: Color(0xFF2563EB),
    logs: [true, true, true, false, true, true],
  ),
  _RecapRow(
    initials: 'BS',
    name: 'Bella Safitri',
    avatarColor: Color(0xFFE6E8FF),
    initialColor: Color(0xFF4F46E5),
    logs: [false, false, true, true, true, true],
  ),
  _RecapRow(
    initials: 'CW',
    name: 'Chandra Wijaya',
    avatarColor: Color(0xFFFFF3C4),
    initialColor: Color(0xFFD97706),
    logs: [true, true, true, true, true, true],
  ),
  _RecapRow(
    initials: 'DP',
    name: 'Diana Putri',
    avatarColor: Color(0xFFFFE1E7),
    initialColor: Color(0xFFE11D48),
    logs: [true, true, true, true, false, false],
  ),
  _RecapRow(
    initials: 'EK',
    name: 'Eko Kurniawan',
    avatarColor: Color(0xFFD1FAE5),
    initialColor: Color(0xFF059669),
    logs: [true, true, true, true, true, true],
  ),
];
