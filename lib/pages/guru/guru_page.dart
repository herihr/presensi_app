import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    final api = ApiService();
    try {
      final responses = await Future.wait([
        api.get('/api/jadwal/guru/${_currentUser.id}'),
        api.get('/api/kelas/'),
        api.get('/api/mata-pelajaran/'),
      ]);

      final kelasById = <int, String>{};
      for (final raw in responses[1] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = _intFromJson(item['id']);
        if (id != null) {
          kelasById[id] = item['nama_kelas']?.toString() ?? 'Kelas';
        }
      }

      final mapelById = <int, String>{};
      for (final raw in responses[2] as List) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = _intFromJson(item['id']);
        if (id != null) {
          mapelById[id] = item['nama_mapel']?.toString() ?? 'Mata Pelajaran';
        }
      }

      final schedules = (responses[0] as List)
          .map((item) => _GuruSchedule.fromJson(
                Map<String, dynamic>.from(item as Map),
                kelasById: kelasById,
                mapelById: mapelById,
              ))
          .where((item) => item.id != 0 && item.kelasId != 0)
          .toList()
        ..sort((a, b) => a.timeRange.compareTo(b.timeRange));

      final todayName = _indonesianDayName(DateTime.now());
      final todaySchedules = schedules
          .where((item) => item.day.toLowerCase() == todayName.toLowerCase())
          .toList();
      return todaySchedules.isEmpty ? schedules : todaySchedules;
    } catch (_) {
      return const [];
    }
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

class _GuruHomeView extends StatelessWidget {
  const _GuruHomeView({
    required this.user,
    required this.profileImage,
    required this.schedulesFuture,
    required this.recapFuture,
    required this.onOpenPresensi,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final User user;
  final ImageProvider? profileImage;
  final Future<List<_GuruSchedule>> schedulesFuture;
  final Future<_RecapData> recapFuture;
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
            jenisKelamin: user.jenisKelamin,
            profileImage: profileImage,
            onProfileTap: onOpenProfile,
            onLogout: onLogout,
          ),
          const SizedBox(height: 26),
          FutureBuilder<_RecapData>(
            future: recapFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return _SectionHeader(
                title: 'Ringkasan Kehadiran',
                actionText: data == null || data.message != null
                    ? 'KELAS'
                    : 'KELAS ${data.className}',
                onTap: () {},
              );
            },
          ),
          const SizedBox(height: 18),
          _AttendanceSummary(recapFuture: recapFuture),
          const SizedBox(height: 28),
          _SectionHeader(
            title: 'Jadwal Mengajar Hari Ini',
            actionText: '',
            titleFontSize: 25,
            onTap: () {},
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<_GuruSchedule>>(
            future: schedulesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ScheduleLoadingCard();
              }

              final schedules = snapshot.data ?? const <_GuruSchedule>[];
              if (schedules.isEmpty) {
                return const _ScheduleEmptyCard();
              }

              return Column(
                children: schedules
                    .map(
                      (schedule) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _ScheduleCard(
                          schedule: schedule,
                          onTap: () => onOpenPresensi(schedule),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

}

class _GuruHeader extends StatelessWidget {
  const _GuruHeader({
    required this.name,
    required this.jenisKelamin,
    required this.profileImage,
    required this.onProfileTap,
    required this.onLogout,
  });

  final String name;
  final String? jenisKelamin;
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
                'Halo, ${_teacherGreeting(jenisKelamin)} $name',
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
    this.titleFontSize,
  });

  final String title;
  final String actionText;
  final VoidCallback onTap;
  final double? titleFontSize;

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
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        if (actionText.isNotEmpty)
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
  const _AttendanceSummary({
    required this.recapFuture,
  });

  final Future<_RecapData> recapFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RecapData>(
      future: recapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const _AttendanceSummaryLoading();
        }

        final data = snapshot.data;
        if (snapshot.hasError || data == null || data.message != null) {
          return _AttendanceSummaryEmpty(
            message: data?.message ?? 'Ringkasan kelas wali belum tersedia.',
          );
        }

        final percentage = data.students.isEmpty
            ? 0
            : ((data.presentCount / data.students.length) * 100).round();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PercentCard(percentage: percentage),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  _CountCard(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF10B981),
                    iconBackground: const Color(0xFFE9FFF5),
                    value: '${data.presentCount}',
                    label: 'HADIR',
                    valueColor: const Color(0xFF009D72),
                  ),
                  const SizedBox(height: 18),
                  _CountCard(
                    icon: Icons.cancel_outlined,
                    iconColor: const Color(0xFFCC0000),
                    iconBackground: const Color(0xFFFFF1F2),
                    value: '${data.absentCount}',
                    label: 'ALPA',
                    valueColor: const Color(0xFFCC0000),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AttendanceSummaryLoading extends StatelessWidget {
  const _AttendanceSummaryLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 236,
      width: double.infinity,
      decoration: _softCardDecoration(),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AttendanceSummaryEmpty extends StatelessWidget {
  const _AttendanceSummaryEmpty({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _softCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
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

class _ScheduleLoadingCard extends StatelessWidget {
  const _ScheduleLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _softCardDecoration(),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Memuat jadwal mengajar...',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyCard extends StatelessWidget {
  const _ScheduleEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _softCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Belum ada jadwal mengajar yang tersimpan di database.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        ],
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

class _GuruStatsView extends StatefulWidget {
  const _GuruStatsView({
    required this.user,
    required this.refreshKey,
    required this.onOpenProfile,
    required this.onLogout,
  });

  final User user;
  final int refreshKey;
  final VoidCallback onOpenProfile;
  final VoidCallback onLogout;

  @override
  State<_GuruStatsView> createState() => _GuruStatsViewState();
}

class _GuruStatsViewState extends State<_GuruStatsView> {
  late Future<_RecapData> _recapFuture;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _recapFuture = _loadRecap();
  }

  @override
  void didUpdateWidget(covariant _GuruStatsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey ||
        oldWidget.user.id != widget.user.id) {
      _recapFuture = _loadRecap();
    }
  }

  Future<_RecapData> _loadRecap() {
    return _loadRecapData(
      widget.user,
      date: _selectedDate,
      fallbackAllSchedules: false,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _recapFuture = _loadRecap();
    });
    try {
      await _recapFuture;
    } catch (_) {
      // Error tetap ditampilkan oleh FutureBuilder.
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Pilih tanggal rekap',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _recapFuture = _loadRecap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_RecapData>(
        future: _recapFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuruHeader(
                  name: _firstName(widget.user.nama),
                  jenisKelamin: widget.user.jenisKelamin,
                  profileImage: _profileImageProvider(widget.user.fotoUrl),
                  onProfileTap: widget.onOpenProfile,
                  onLogout: widget.onLogout,
                ),
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
                            data == null
                                ? 'Memuat kelas wali...'
                                : data.message ?? 'Pemantauan ${data.className}',
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
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded, size: 22),
                      label: Text(_dateLabel(_selectedDate)),
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
                if (snapshot.connectionState == ConnectionState.waiting && data == null)
                  const _StatsLoadingCard()
                else if (snapshot.hasError)
                  _StatsMessageCard(
                    icon: Icons.cloud_off_rounded,
                    message: snapshot.error.toString().replaceFirst('Exception: ', ''),
                  )
                else if (data == null || data.message != null)
                  _StatsMessageCard(
                    icon: Icons.info_outline_rounded,
                    message: data?.message ?? 'Data rekapan belum tersedia.',
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _RecapMetricCard(
                          label: 'HADIR',
                          value: '${data.presentCount}',
                          valueColor: const Color(0xFF004AD8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RecapMetricCard(
                          label: 'TIDAK HADIR',
                          value: '${data.absentCount}',
                          valueColor: const Color(0xFFB80F0F),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RecapMetricCard(
                          label: 'TOTAL JP',
                          value: '${data.columns.length}',
                          valueColor: const Color(0xFF943700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _StudentLogsCard(data: data),
                  const SizedBox(height: 28),
                  _ExportReportCard(data: data),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsLoadingCard extends StatelessWidget {
  const _StatsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _softCardDecoration(),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _StatsMessageCard extends StatelessWidget {
  const _StatsMessageCard({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: _softCardDecoration(),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF64748B)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
        ],
      ),
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
  const _StudentLogsCard({
    required this.data,
  });

  final _RecapData data;

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
                        ...data.columns.map(
                          (column) => SizedBox(
                            width: 66,
                            child: Center(
                              child: Tooltip(
                                message: column.mapelName,
                                child: Text(
                                  'J${column.number}',
                                  style: const TextStyle(
                                    color: Color(0xFF737686),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.rows.isEmpty || data.columns.isEmpty)
                    SizedBox(
                      height: 82,
                      width: 360,
                      child: Center(
                        child: Text(
                          data.columns.isEmpty
                              ? 'Tidak ada jadwal pada tanggal ini.'
                              : 'Belum ada siswa pada kelas ini.',
                          style: const TextStyle(color: Color(0xFF737686)),
                        ),
                      ),
                    )
                  else
                    ...data.rows.map((row) => _StudentLogRow(row: row)),
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
  const _ExportReportCard({
    required this.data,
  });

  final _RecapData data;

  @override
  Widget build(BuildContext context) {
    return _ReportDownloadPanel(data: data);
  }
}

enum _ReportPeriod { daily, weekly, monthly }

enum _ReportFormat { excel, pdf }

class _ReportDownloadPanel extends StatefulWidget {
  const _ReportDownloadPanel({
    required this.data,
  });

  final _RecapData data;

  @override
  State<_ReportDownloadPanel> createState() => _ReportDownloadPanelState();
}

class _ReportDownloadPanelState extends State<_ReportDownloadPanel> {
  static final Set<String> _autoDownloadedMonths = {};

  _ReportPeriod _period = _ReportPeriod.monthly;
  _ReportFormat _format = _ReportFormat.excel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoDownloadMonthlyIfDue();
    });
  }

  String get _periodLabel {
    switch (_period) {
      case _ReportPeriod.daily:
        return 'Harian';
      case _ReportPeriod.weekly:
        return 'Mingguan';
      case _ReportPeriod.monthly:
        return 'Bulanan';
    }
  }

  String get _formatLabel {
    switch (_format) {
      case _ReportFormat.excel:
        return 'Excel';
      case _ReportFormat.pdf:
        return 'PDF';
    }
  }

  Future<void> _autoDownloadMonthlyIfDue() async {
    final today = DateTime.now();
    if (!_isLastDayOfMonth(today)) return;

    final key = '${widget.data.className}-${today.year}-${today.month}';
    if (_autoDownloadedMonths.contains(key)) return;
    _autoDownloadedMonths.add(key);

    try {
      await _saveReport(
        period: _ReportPeriod.monthly,
        format: _ReportFormat.excel,
        automatic: true,
      );
    } catch (error) {
      debugPrint('Download otomatis laporan bulanan gagal: $error');
    }
  }

  Future<void> _download() async {
    try {
      final path = await _saveReport(
        period: _period,
        format: _format,
        automatic: false,
      );
      if (!mounted) return;
      await AppAlert.success(
        context,
        title: 'Laporan Terunduh',
        message: 'Laporan $_periodLabel format $_formatLabel berhasil disimpan:\n$path',
      );
    } catch (error) {
      if (!mounted) return;
      await AppAlert.error(
        context,
        title: 'Gagal',
        message: 'Laporan belum bisa diunduh. $error',
      );
    }
  }

  Future<String> _saveReport({
    required _ReportPeriod period,
    required _ReportFormat format,
    required bool automatic,
  }) async {
    final today = DateTime.now();
    final extension = format == _ReportFormat.excel ? 'xls' : 'pdf';
    final autoSuffix = automatic ? '_otomatis' : '';
    final reportDate = period == _ReportPeriod.daily ? widget.data.date : today;
    final fileName =
        'laporan_presensi_${_safeFileName(widget.data.className)}_${_periodFileKey(period)}_${_dateKey(reportDate)}$autoSuffix.$extension';
    final content = period == _ReportPeriod.weekly
        ? await _buildWeeklyReportContent(
            format: format,
            generatedAt: today,
          )
        : format == _ReportFormat.excel
            ? _buildReportExcel(
                data: widget.data,
                period: period,
                generatedAt: today,
              )
            : _buildReportPdf(
                data: widget.data,
                period: period,
                generatedAt: today,
              );
    final mimeType = format == _ReportFormat.excel
        ? 'application/vnd.ms-excel'
        : 'application/pdf';
    return _writeReportFile(
      fileName: fileName,
      content: content,
      mimeType: mimeType,
    );
  }

  Future<String> _buildWeeklyReportContent({
    required _ReportFormat format,
    required DateTime generatedAt,
  }) async {
    final weeklyData = await _loadWeeklyReportData(
      baseData: widget.data,
      generatedAt: generatedAt,
    );
    return format == _ReportFormat.excel
        ? _buildWeeklyReportExcel(data: weeklyData)
        : _buildWeeklyReportPdf(data: weeklyData);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.file_download_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unduh Laporan Presensi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bulanan otomatis disiapkan di tanggal terakhir bulan berjalan.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.82),
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Periode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          _ReportSegmentedControl<_ReportPeriod>(
            value: _period,
            items: const [
              _ReportOption(value: _ReportPeriod.daily, label: 'Hari'),
              _ReportOption(value: _ReportPeriod.weekly, label: 'Minggu'),
              _ReportOption(value: _ReportPeriod.monthly, label: 'Bulan'),
            ],
            onChanged: (value) => setState(() => _period = value),
          ),
          const SizedBox(height: 16),
          const Text(
            'Format',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _ReportFormatButton(
                  label: 'Excel',
                  icon: Icons.table_chart_rounded,
                  selected: _format == _ReportFormat.excel,
                  onTap: () => setState(() => _format = _ReportFormat.excel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReportFormatButton(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  selected: _format == _ReportFormat.pdf,
                  onTap: () => setState(() => _format = _ReportFormat.pdf),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded),
              label: Text('Unduh $_formatLabel $_periodLabel'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportOption<T> {
  const _ReportOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class _ReportSegmentedControl<T> extends StatelessWidget {
  const _ReportSegmentedControl({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<_ReportOption<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.13),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: InkWell(
                  onTap: () => onChanged(item.value),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.value == value ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: item.value == value
                              ? const Color(0xFF2563EB)
                              : Colors.white.withOpacity(0.86),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ReportFormatButton extends StatelessWidget {
  const _ReportFormatButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF2563EB) : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF2563EB) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isLastDayOfMonth(DateTime date) {
  final tomorrow = date.add(const Duration(days: 1));
  return tomorrow.month != date.month;
}

String _periodFileKey(_ReportPeriod period) {
  switch (period) {
    case _ReportPeriod.daily:
      return 'harian';
    case _ReportPeriod.weekly:
      return 'mingguan';
    case _ReportPeriod.monthly:
      return 'bulanan';
  }
}

String _periodTitle(_ReportPeriod period) {
  switch (period) {
    case _ReportPeriod.daily:
      return 'Harian';
    case _ReportPeriod.weekly:
      return 'Mingguan';
    case _ReportPeriod.monthly:
      return 'Bulanan';
  }
}

String _safeFileName(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  return normalized.replaceAll(RegExp(r'[^a-z0-9_\-]'), '');
}

String _htmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

int _rowPresentSlots(_RecapRow row) {
  return row.logs.where((item) => item).length;
}

int _rowAttendancePercent(_RecapRow row) {
  if (row.logs.isEmpty) return 0;
  return ((_rowPresentSlots(row) / row.logs.length) * 100).round();
}

String _excelStyles() {
  return '''
body {
  font-family: Arial, Helvetica, sans-serif;
  color: #111827;
}
table.report {
  border-collapse: collapse;
  width: 100%;
}
td, th {
  border: 1px solid #E5E7EB;
  padding: 9px 12px;
  vertical-align: middle;
}
.brand {
  background: #2563EB;
  color: #FFFFFF;
  font-size: 22px;
  font-weight: 700;
}
.subtitle {
  background: #DBEAFE;
  color: #1E3A8A;
  font-weight: 700;
}
.meta-label {
  background: #F8FAFC;
  color: #64748B;
  font-weight: 700;
  width: 160px;
}
.meta-value {
  color: #111827;
  font-weight: 700;
}
.card-label {
  background: #F8FAFC;
  color: #64748B;
  font-size: 11px;
  font-weight: 700;
}
.card-blue {
  background: #EFF6FF;
  color: #2563EB;
  font-size: 22px;
  font-weight: 700;
}
.card-green {
  background: #ECFDF5;
  color: #047857;
  font-size: 22px;
  font-weight: 700;
}
.card-red {
  background: #FEF2F2;
  color: #B91C1C;
  font-size: 22px;
  font-weight: 700;
}
.card-brown {
  background: #FFF7ED;
  color: #9A3412;
  font-size: 22px;
  font-weight: 700;
}
.section {
  background: #F1F5F9;
  color: #0F172A;
  font-size: 16px;
  font-weight: 700;
}
.table-head {
  background: #2563EB;
  color: #FFFFFF;
  font-weight: 700;
  text-align: center;
}
.center {
  text-align: center;
}
.name {
  font-weight: 700;
}
.hadir {
  background: #ECFDF5;
  color: #047857;
  font-weight: 700;
}
.alpa {
  background: #FEF2F2;
  color: #B91C1C;
  font-weight: 700;
}
.muted {
  color: #64748B;
}
.note {
  background: #F8FAFC;
  color: #64748B;
  font-size: 11px;
}
.spacer td {
  border: 0;
  height: 14px;
}
.page-break {
  page-break-before: always;
  mso-page-break-before: always;
}
''';
}

String _buildReportExcel({
  required _RecapData data,
  required _ReportPeriod period,
  required DateTime generatedAt,
}) {
  final tableColumnCount = 4 + data.columns.length;
  final layoutColumnCount = tableColumnCount < 6 ? 6 : tableColumnCount;
  final totalStudents = data.students.length;
  final presentPercent =
      totalStudents == 0 ? 0 : ((data.presentCount / totalStudents) * 100).round();
  final buffer = StringBuffer()
    ..writeln('<html>')
    ..writeln('<head>')
    ..writeln('<meta charset="UTF-8">')
    ..writeln('<style>')
    ..writeln(_excelStyles())
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<table class="report">')
    ..writeln(
      '<tr><td class="brand" colspan="$layoutColumnCount">PresenSatu - Laporan Presensi ${_htmlEscape(_periodTitle(period))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="subtitle" colspan="$layoutColumnCount">Kelas ${_htmlEscape(data.className)} | ${_htmlEscape(data.dayName)}, ${_htmlEscape(_dateLabel(data.date))} | Dibuat ${_htmlEscape(_dateLabel(generatedAt))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Kelas</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(data.className)}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Tanggal rekap</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(_dateLabel(data.date))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Tanggal dibuat</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(_dateLabel(generatedAt))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Total JP</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${data.columns.length}</td></tr>',
    )
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="card-label" colspan="2">TOTAL SISWA</td><td class="card-label" colspan="2">HADIR</td><td class="card-label" colspan="2">ALPA</td></tr>',
    )
    ..writeln(
      '<tr><td class="card-blue" colspan="2">$totalStudents siswa</td><td class="card-green" colspan="2">${data.presentCount} siswa</td><td class="card-red" colspan="2">${data.absentCount} siswa</td></tr>',
    )
    ..writeln(
      '<tr><td class="section" colspan="$layoutColumnCount">Ringkasan: Persentase hadir $presentPercent% dari $totalStudents siswa</td></tr>',
    )
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln('<tr><td class="section" colspan="$layoutColumnCount">Log Kehadiran Siswa</td></tr>')
    ..write(
      '<tr><th class="table-head">No</th><th class="table-head">Nama Siswa</th><th class="table-head">Status</th>',
    );

  for (final column in data.columns) {
    buffer.write(
      '<th class="table-head">J${column.number}<br>${_htmlEscape(column.mapelName)}</th>',
    );
  }
  buffer.writeln('<th class="table-head">Persentase</th></tr>');

  for (var index = 0; index < data.rows.length; index++) {
    final row = data.rows[index];
    final present = row.logs.any((item) => item);
    buffer
      ..write('<tr>')
      ..write('<td class="center">${index + 1}</td>')
      ..write('<td class="name">${_htmlEscape(row.name)}</td>')
      ..write(
        '<td class="center ${present ? 'hadir' : 'alpa'}">${present ? 'Hadir' : 'Alpa'}</td>',
      );
    for (final log in row.logs) {
      buffer.write(
        '<td class="center ${log ? 'hadir' : 'alpa'}">${log ? 'Hadir' : 'Tidak Hadir'}</td>',
      );
    }
    buffer.write('<td class="center name">${_rowAttendancePercent(row)}%</td>');
    buffer.writeln('</tr>');
  }

  buffer
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="note" colspan="$layoutColumnCount">Keterangan: Hadir dihitung per siswa jika minimal memiliki satu JP hadir. Persentase baris dihitung dari JP hadir dibagi total JP pada hari tersebut.</td></tr>',
    )
    ..writeln('</table>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

Future<_WeeklyReportData> _loadWeeklyReportData({
  required _RecapData baseData,
  required DateTime generatedAt,
}) async {
  if (baseData.classId == 0) {
    throw Exception('Kelas wali belum ditemukan untuk membuat laporan mingguan.');
  }

  final api = ApiService();
  final endDate = DateTime(generatedAt.year, generatedAt.month, generatedAt.day);
  final startDate = endDate.subtract(const Duration(days: 6));
  final dates = List<DateTime>.generate(
    7,
    (index) => startDate.add(Duration(days: index)),
  );

  final responses = await Future.wait<dynamic>([
    api.get('/api/siswa/kelas/${baseData.classId}'),
    api.get('/api/jadwal/kelas/${baseData.classId}'),
    api.get('/api/mata-pelajaran/'),
    ...dates.map((date) => api.get('/api/presensi/tanggal/${_dateKey(date)}')),
  ]);

  final students = (responses[0] as List)
      .map((item) => _RecapStudent.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final mapelById = <int, String>{};
  for (final raw in responses[2] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final id = _intFromJson(item['id']);
    if (id != null) mapelById[id] = item['nama_mapel']?.toString() ?? 'Mapel';
  }

  final allSchedules = (responses[1] as List)
      .map((item) => _RecapSchedule.fromJson(
            Map<String, dynamic>.from(item as Map),
            mapelById: mapelById,
          ))
      .where((item) => item.id != 0)
      .toList();

  final presentSlotsByStudent = <int, int>{
    for (final student in students) student.id: 0,
  };
  final totalSlotsByStudent = <int, int>{
    for (final student in students) student.id: 0,
  };
  final dayReports = <_WeeklyDayReport>[];

  for (var dateIndex = 0; dateIndex < dates.length; dateIndex++) {
    final date = dates[dateIndex];
    final dayName = _indonesianDayName(date);
    final presensiItems = (responses[3 + dateIndex] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final presentKeys = <String>{};
    final presentScheduleIds = <int>{};
    for (final item in presensiItems) {
      final status = item['status']?.toString().trim().toLowerCase();
      if (status != 'hadir') continue;
      final siswaId = _intFromJson(item['siswa_id']);
      final jadwalId = _intFromJson(item['jadwal_id']);
      if (siswaId != null && jadwalId != null) {
        presentKeys.add('$siswaId:$jadwalId');
        presentScheduleIds.add(jadwalId);
      }
    }

    final schedules = allSchedules
        .where(
          (item) =>
              _sameDayName(item.day, dayName) ||
              presentScheduleIds.contains(item.id),
        )
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final columns = <_RecapColumn>[];
    var jpNumber = 1;
    for (final schedule in schedules) {
      for (var index = 0; index < schedule.lessonHours; index++) {
        columns.add(
          _RecapColumn(
            number: jpNumber++,
            scheduleId: schedule.id,
            mapelName: schedule.mapelName,
          ),
        );
      }
    }

    final rows = students.map((student) {
      final logs = columns
          .map((column) => presentKeys.contains('${student.id}:${column.scheduleId}'))
          .toList();
      presentSlotsByStudent[student.id] =
          (presentSlotsByStudent[student.id] ?? 0) + logs.where((item) => item).length;
      totalSlotsByStudent[student.id] =
          (totalSlotsByStudent[student.id] ?? 0) + logs.length;
      return _RecapRow(
        initials: _initials(student.name),
        name: student.name,
        avatarColor: _avatarColor(student.id),
        initialColor: _initialColor(student.id),
        logs: logs,
      );
    }).toList();

    dayReports.add(
      _WeeklyDayReport(
        date: date,
        dayName: dayName,
        columns: columns,
        rows: rows,
      ),
    );
  }

  final summaries = students.map((student) {
    return _WeeklyStudentSummary(
      name: student.name,
      presentSlots: presentSlotsByStudent[student.id] ?? 0,
      totalSlots: totalSlotsByStudent[student.id] ?? 0,
    );
  }).toList();

  return _WeeklyReportData(
    className: baseData.className,
    startDate: startDate,
    endDate: endDate,
    generatedAt: generatedAt,
    students: students,
    dayReports: dayReports,
    summaries: summaries,
  );
}

String _buildWeeklyReportExcel({
  required _WeeklyReportData data,
}) {
  var layoutColumnCount = 6;
  for (final day in data.dayReports) {
    final count = 4 + day.columns.length;
    if (count > layoutColumnCount) layoutColumnCount = count;
  }

  final buffer = StringBuffer()
    ..writeln('<html>')
    ..writeln('<head>')
    ..writeln('<meta charset="UTF-8">')
    ..writeln('<style>')
    ..writeln(_excelStyles())
    ..writeln('</style>')
    ..writeln('</head>')
    ..writeln('<body>')
    ..writeln('<table class="report">')
    ..writeln(
      '<tr><td class="brand" colspan="$layoutColumnCount">PresenSatu - Laporan Presensi Mingguan</td></tr>',
    )
    ..writeln(
      '<tr><td class="subtitle" colspan="$layoutColumnCount">Kelas ${_htmlEscape(data.className)} | ${_htmlEscape(data.rangeLabel)} | Dibuat ${_htmlEscape(_dateLabel(data.generatedAt))}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Kelas</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(data.className)}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Rentang laporan</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(data.rangeLabel)}</td></tr>',
    )
    ..writeln(
      '<tr><td class="meta-label">Tanggal dibuat</td><td class="meta-value" colspan="${layoutColumnCount - 1}">${_htmlEscape(_dateLabel(data.generatedAt))}</td></tr>',
    )
    ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="card-label" colspan="2">TOTAL SISWA</td><td class="card-label" colspan="2">RATA-RATA HADIR</td><td class="card-label" colspan="2">TOTAL JP MINGGUAN</td></tr>',
    )
    ..writeln(
      '<tr><td class="card-blue" colspan="2">${data.students.length} siswa</td><td class="card-green" colspan="2">${data.averagePercent}%</td><td class="card-brown" colspan="2">${data.totalLessonSlots} JP</td></tr>',
    )
    ..writeln(
      '<tr><td class="section" colspan="$layoutColumnCount">Log Kehadiran 7 Hari Terakhir</td></tr>',
    );

  for (final day in data.dayReports) {
    final presentCount = day.columns.isEmpty
        ? 0
        : day.rows.where((row) => row.logs.any((item) => item)).length;
    final absentCount = day.columns.isEmpty
        ? 0
        : day.rows.where((row) => !row.logs.any((item) => item)).length;
    final dayPercent = data.students.isEmpty || day.columns.isEmpty
        ? 0
        : ((presentCount / data.students.length) * 100).round();
    buffer
      ..writeln('<tr class="spacer"><td colspan="$layoutColumnCount"></td></tr>')
      ..writeln(
        '<tr><td class="section" colspan="$layoutColumnCount">${_htmlEscape(day.dayName)}, ${_htmlEscape(_dateLabel(day.date))}</td></tr>',
      )
      ..writeln(
        '<tr><td class="meta-label">Ringkasan hari</td><td class="meta-value" colspan="${layoutColumnCount - 1}">Hadir $presentCount siswa | Alpa $absentCount siswa | Total JP ${day.columns.length} | Persentase hadir $dayPercent%</td></tr>',
      )
      ..write(
        '<tr><th class="table-head">No</th><th class="table-head">Nama Siswa</th><th class="table-head">Status</th>',
      );
    for (final column in day.columns) {
      buffer.write(
        '<th class="table-head">J${column.number}<br>${_htmlEscape(column.mapelName)}</th>',
      );
    }
    buffer.writeln('<th class="table-head">Persentase</th></tr>');

    for (var index = 0; index < day.rows.length; index++) {
      final row = day.rows[index];
      final present = row.logs.any((item) => item);
      final statusLabel = day.columns.isEmpty
          ? 'Tidak ada jadwal'
          : present
              ? 'Hadir'
              : 'Alpa';
      final statusClass = present
          ? 'hadir'
          : day.columns.isEmpty
              ? ''
              : 'alpa';
      buffer
        ..write('<tr>')
        ..write('<td class="center">${index + 1}</td>')
        ..write('<td class="name">${_htmlEscape(row.name)}</td>')
        ..write(
          '<td class="center $statusClass">${_htmlEscape(statusLabel)}</td>',
        );
      for (final log in row.logs) {
        buffer.write(
          '<td class="center ${log ? 'hadir' : 'alpa'}">${log ? 'Hadir' : 'Tidak Hadir'}</td>',
        );
      }
      buffer
        ..write('<td class="center name">${_rowAttendancePercent(row)}%</td>')
        ..writeln('</tr>');
    }
  }

  buffer
    ..writeln('<tr class="spacer page-break"><td colspan="$layoutColumnCount"></td></tr>')
    ..writeln(
      '<tr><td class="brand" colspan="$layoutColumnCount">Rangkuman Kehadiran Mingguan</td></tr>',
    )
    ..writeln(
      '<tr><td class="subtitle" colspan="$layoutColumnCount">Persentase tiap siswa dihitung dari total JP hadir selama ${_htmlEscape(data.rangeLabel)}</td></tr>',
    )
    ..writeln(
      '<tr><th class="table-head">No</th><th class="table-head">Nama Siswa</th><th class="table-head">Hadir JP</th><th class="table-head">Total JP</th><th class="table-head">Persentase</th><th class="table-head">Keterangan</th></tr>',
    );
  for (var index = 0; index < data.summaries.length; index++) {
    final summary = data.summaries[index];
    final statusClass = summary.percent >= 75 ? 'hadir' : 'alpa';
    final note = summary.totalSlots == 0
        ? 'Tidak ada jadwal'
        : summary.percent >= 75
            ? 'Baik'
            : 'Perlu perhatian';
    buffer
      ..write('<tr>')
      ..write('<td class="center">${index + 1}</td>')
      ..write('<td class="name">${_htmlEscape(summary.name)}</td>')
      ..write('<td class="center hadir">${summary.presentSlots}</td>')
      ..write('<td class="center">${summary.totalSlots}</td>')
      ..write('<td class="center name">${summary.percent}%</td>')
      ..write('<td class="center $statusClass">${_htmlEscape(note)}</td>')
      ..writeln('</tr>');
  }

  buffer
    ..writeln(
      '<tr><td class="note" colspan="$layoutColumnCount">Keterangan: Hasil mingguan mengambil 7 hari terakhir sejak laporan dibuat. Status Baik dipakai jika persentase hadir minimal 75%.</td></tr>',
    )
    ..writeln('</table>')
    ..writeln('</body>')
    ..writeln('</html>');
  return buffer.toString();
}

String _buildReportPdf({
  required _RecapData data,
  required _ReportPeriod period,
  required DateTime generatedAt,
}) {
  final content = StringBuffer();

  void fillRect(
    double x,
    double y,
    double width,
    double height,
    String color,
  ) {
    content.writeln('q $color rg $x $y $width $height re f Q');
  }

  void strokeRect(
    double x,
    double y,
    double width,
    double height,
    String color, {
    double lineWidth = 1,
  }) {
    content.writeln('q $color RG $lineWidth w $x $y $width $height re S Q');
  }

  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    String color, {
    double lineWidth = 1,
  }) {
    content.writeln('q $color RG $lineWidth w $x1 $y1 m $x2 $y2 l S Q');
  }

  void text(
    String value,
    double x,
    double y, {
    int size = 10,
    String font = 'F1',
    String color = '0.090 0.110 0.160',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font $size Tf')
      ..writeln('$x $y Td')
      ..writeln('(${_pdfEscape(value)}) Tj')
      ..writeln('ET');
  }

  final title = 'Laporan Presensi ${_periodTitle(period)}';
  final totalStudents = data.students.length;
  final presentPercent =
      totalStudents == 0 ? 0 : ((data.presentCount / totalStudents) * 100).round();
  final periodLabel = _periodTitle(period);

  fillRect(0, 742, 595, 100, '0.145 0.388 0.922');
  text('PresenSatu', 42, 804, size: 18, font: 'F2', color: '1 1 1');
  text(title, 42, 778, size: 24, font: 'F2', color: '1 1 1');
  text(
    'Kelas ${data.className}  |  ${data.dayName}, ${_dateLabel(data.date)}  |  Dibuat ${_dateLabel(generatedAt)}',
    42,
    758,
    size: 10,
    color: '0.890 0.940 1',
  );

  fillRect(42, 674, 156, 46, '0.937 0.965 1');
  fillRect(219, 674, 156, 46, '0.925 0.988 0.961');
  fillRect(396, 674, 156, 46, '1 0.945 0.945');
  strokeRect(42, 674, 156, 46, '0.827 0.890 1');
  strokeRect(219, 674, 156, 46, '0.733 0.949 0.847');
  strokeRect(396, 674, 156, 46, '0.984 0.800 0.800');
  text('TOTAL SISWA', 56, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('$totalStudents', 56, 684, size: 19, font: 'F2', color: '0.145 0.388 0.922');
  text('HADIR', 233, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.presentCount} siswa', 233, 684, size: 19, font: 'F2', color: '0.047 0.545 0.310');
  text('ALPA', 410, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.absentCount} siswa', 410, 684, size: 19, font: 'F2', color: '0.796 0 0');

  fillRect(42, 626, 510, 30, '0.980 0.984 0.992');
  strokeRect(42, 626, 510, 30, '0.894 0.914 0.941');
  text('Ringkasan', 56, 638, size: 12, font: 'F2');
  text(
    'Persentase hadir $presentPercent%  |  Total JP ${data.columns.length}  |  Periode $periodLabel',
    150,
    638,
    size: 10,
    color: '0.392 0.455 0.545',
  );

  text('Log Kehadiran Siswa', 42, 590, size: 15, font: 'F2');
  fillRect(42, 556, 510, 26, '0.145 0.388 0.922');
  text('NO', 54, 565, size: 9, font: 'F2', color: '1 1 1');
  text('NAMA SISWA', 92, 565, size: 9, font: 'F2', color: '1 1 1');
  text('STATUS', 278, 565, size: 9, font: 'F2', color: '1 1 1');
  text('DETAIL JP', 356, 565, size: 9, font: 'F2', color: '1 1 1');
  text('PERSEN', 500, 565, size: 9, font: 'F2', color: '1 1 1');

  var y = 530.0;
  for (var index = 0; index < data.rows.length; index++) {
    if (y < 92) break;
    final row = data.rows[index];
    final present = row.logs.any((item) => item);
    final detail = row.logs.isEmpty
        ? '-'
        : row.logs
            .asMap()
            .entries
            .map((entry) => 'J${entry.key + 1}:${entry.value ? 'H' : 'A'}')
            .join('  ');
    final rowColor = index.isEven ? '1 1 1' : '0.980 0.984 0.992';
    fillRect(42, y - 8, 510, 28, rowColor);
    line(42, y - 8, 552, y - 8, '0.894 0.914 0.941');
    text('${index + 1}', 56, y, size: 10);
    text(row.name, 92, y, size: 10, font: 'F2');
    text(
      present ? 'Hadir' : 'Alpa',
      278,
      y,
      size: 10,
      font: 'F2',
      color: present ? '0.047 0.545 0.310' : '0.796 0 0',
    );
    text(detail, 356, y, size: 9, color: '0.392 0.455 0.545');
    text('${_rowAttendancePercent(row)}%', 508, y, size: 10, font: 'F2');
    y -= 28;
  }

  line(42, 76, 552, 76, '0.894 0.914 0.941');
  text('Keterangan: H = Hadir, A = Alpa/Tidak Hadir', 42, 58, size: 9, color: '0.392 0.455 0.545');
  text('Dokumen dibuat otomatis oleh PresenSatu', 360, 58, size: 9, color: '0.392 0.455 0.545');

  final stream = content.toString();
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
    '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
    '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 6 0 R >> >> /Contents 5 0 R >>\nendobj\n',
    '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
    '5 0 obj\n<< /Length ${stream.length} >>\nstream\n$stream\nendstream\nendobj\n',
    '6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
  ];

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var offset = buffer.length;
  for (final object in objects) {
    offsets.add(offset);
    buffer.write(object);
    offset += object.length;
  }

  final xrefOffset = offset;
  buffer
    ..writeln('xref')
    ..writeln('0 ${objects.length + 1}')
    ..writeln('0000000000 65535 f ');
  for (var index = 1; index < offsets.length; index++) {
    buffer.writeln('${offsets[index].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln('$xrefOffset')
    ..writeln('%%EOF');
  return buffer.toString();
}

String _buildWeeklyReportPdf({
  required _WeeklyReportData data,
}) {
  final pages = <String>[
    for (final day in data.dayReports) _buildWeeklyDayPdfPage(data, day),
    _buildWeeklySummaryPdfPage(data),
  ];
  return _buildPdfDocument(pages);
}

String _buildWeeklyDayPdfPage(_WeeklyReportData data, _WeeklyDayReport day) {
  final content = StringBuffer();

  void fillRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color rg $x $y $width $height re f Q');
  }

  void strokeRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color RG 1 w $x $y $width $height re S Q');
  }

  void line(double x1, double y1, double x2, double y2, String color) {
    content.writeln('q $color RG 1 w $x1 $y1 m $x2 $y2 l S Q');
  }

  void text(
    String value,
    double x,
    double y, {
    int size = 10,
    String font = 'F1',
    String color = '0.090 0.110 0.160',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font $size Tf')
      ..writeln('$x $y Td')
      ..writeln('(${_pdfEscape(value)}) Tj')
      ..writeln('ET');
  }

  final presentCount = day.columns.isEmpty
      ? 0
      : day.rows.where((row) => row.logs.any((item) => item)).length;
  final absentCount = day.columns.isEmpty
      ? 0
      : day.rows.where((row) => !row.logs.any((item) => item)).length;
  final percent = data.students.isEmpty || day.columns.isEmpty
      ? 0
      : ((presentCount / data.students.length) * 100).round();

  fillRect(0, 742, 595, 100, '0.145 0.388 0.922');
  text('PresenSatu', 42, 804, size: 18, font: 'F2', color: '1 1 1');
  text('Laporan Presensi Mingguan', 42, 778, size: 24, font: 'F2', color: '1 1 1');
  text(
    'Kelas ${data.className}  |  ${day.dayName}, ${_dateLabel(day.date)}  |  Rentang ${data.rangeLabel}',
    42,
    758,
    size: 10,
    color: '0.890 0.940 1',
  );

  fillRect(42, 674, 156, 46, '0.937 0.965 1');
  fillRect(219, 674, 156, 46, '0.925 0.988 0.961');
  fillRect(396, 674, 156, 46, '1 0.945 0.945');
  strokeRect(42, 674, 156, 46, '0.827 0.890 1');
  strokeRect(219, 674, 156, 46, '0.733 0.949 0.847');
  strokeRect(396, 674, 156, 46, '0.984 0.800 0.800');
  text('TOTAL SISWA', 56, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.students.length}', 56, 684, size: 19, font: 'F2', color: '0.145 0.388 0.922');
  text('HADIR', 233, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('$presentCount siswa', 233, 684, size: 19, font: 'F2', color: '0.047 0.545 0.310');
  text('ALPA', 410, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('$absentCount siswa', 410, 684, size: 19, font: 'F2', color: '0.796 0 0');

  fillRect(42, 626, 510, 30, '0.980 0.984 0.992');
  strokeRect(42, 626, 510, 30, '0.894 0.914 0.941');
  text('Ringkasan', 56, 638, size: 12, font: 'F2');
  text(
    'Persentase hadir $percent%  |  Total JP ${day.columns.length}  |  Dibuat ${_dateLabel(data.generatedAt)}',
    150,
    638,
    size: 10,
    color: '0.392 0.455 0.545',
  );

  text('Log Kehadiran Siswa', 42, 590, size: 15, font: 'F2');
  fillRect(42, 556, 510, 26, '0.145 0.388 0.922');
  text('NO', 54, 565, size: 9, font: 'F2', color: '1 1 1');
  text('NAMA SISWA', 92, 565, size: 9, font: 'F2', color: '1 1 1');
  text('STATUS', 278, 565, size: 9, font: 'F2', color: '1 1 1');
  text('DETAIL JP', 356, 565, size: 9, font: 'F2', color: '1 1 1');
  text('PERSEN', 500, 565, size: 9, font: 'F2', color: '1 1 1');

  var y = 530.0;
  for (var index = 0; index < day.rows.length; index++) {
    if (y < 92) break;
    final row = day.rows[index];
    final present = row.logs.any((item) => item);
    final statusLabel = day.columns.isEmpty
        ? 'Tidak ada jadwal'
        : present
            ? 'Hadir'
            : 'Alpa';
    final detail = row.logs.isEmpty
        ? '-'
        : row.logs
            .asMap()
            .entries
            .map((entry) => 'J${entry.key + 1}:${entry.value ? 'H' : 'A'}')
            .join('  ');
    fillRect(42, y - 8, 510, 28, index.isEven ? '1 1 1' : '0.980 0.984 0.992');
    line(42, y - 8, 552, y - 8, '0.894 0.914 0.941');
    text('${index + 1}', 56, y, size: 10);
    text(row.name, 92, y, size: 10, font: 'F2');
    text(
      statusLabel,
      278,
      y,
      size: 10,
      font: 'F2',
      color: present ? '0.047 0.545 0.310' : '0.796 0 0',
    );
    text(detail, 356, y, size: 9, color: '0.392 0.455 0.545');
    text('${_rowAttendancePercent(row)}%', 508, y, size: 10, font: 'F2');
    y -= 28;
  }

  if (day.columns.isEmpty) {
    text('Tidak ada jadwal pada hari ini.', 42, 520, size: 11, color: '0.392 0.455 0.545');
  }

  line(42, 76, 552, 76, '0.894 0.914 0.941');
  text('Keterangan: H = Hadir, A = Alpa/Tidak Hadir', 42, 58, size: 9, color: '0.392 0.455 0.545');
  text('Dokumen dibuat otomatis oleh PresenSatu', 360, 58, size: 9, color: '0.392 0.455 0.545');
  return content.toString();
}

String _buildWeeklySummaryPdfPage(_WeeklyReportData data) {
  final content = StringBuffer();

  void fillRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color rg $x $y $width $height re f Q');
  }

  void strokeRect(double x, double y, double width, double height, String color) {
    content.writeln('q $color RG 1 w $x $y $width $height re S Q');
  }

  void line(double x1, double y1, double x2, double y2, String color) {
    content.writeln('q $color RG 1 w $x1 $y1 m $x2 $y2 l S Q');
  }

  void text(
    String value,
    double x,
    double y, {
    int size = 10,
    String font = 'F1',
    String color = '0.090 0.110 0.160',
  }) {
    content
      ..writeln('BT')
      ..writeln('$color rg')
      ..writeln('/$font $size Tf')
      ..writeln('$x $y Td')
      ..writeln('(${_pdfEscape(value)}) Tj')
      ..writeln('ET');
  }

  fillRect(0, 742, 595, 100, '0.145 0.388 0.922');
  text('PresenSatu', 42, 804, size: 18, font: 'F2', color: '1 1 1');
  text('Rangkuman Kehadiran Mingguan', 42, 778, size: 24, font: 'F2', color: '1 1 1');
  text(
    'Kelas ${data.className}  |  ${data.rangeLabel}  |  Dibuat ${_dateLabel(data.generatedAt)}',
    42,
    758,
    size: 10,
    color: '0.890 0.940 1',
  );

  fillRect(42, 674, 156, 46, '0.937 0.965 1');
  fillRect(219, 674, 156, 46, '0.925 0.988 0.961');
  fillRect(396, 674, 156, 46, '1 0.945 0.945');
  strokeRect(42, 674, 156, 46, '0.827 0.890 1');
  strokeRect(219, 674, 156, 46, '0.733 0.949 0.847');
  strokeRect(396, 674, 156, 46, '0.984 0.800 0.800');
  text('TOTAL SISWA', 56, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.students.length}', 56, 684, size: 19, font: 'F2', color: '0.145 0.388 0.922');
  text('RATA-RATA', 233, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.averagePercent}%', 233, 684, size: 19, font: 'F2', color: '0.047 0.545 0.310');
  text('TOTAL JP', 410, 704, size: 8, font: 'F2', color: '0.392 0.455 0.545');
  text('${data.totalLessonSlots}', 410, 684, size: 19, font: 'F2', color: '0.569 0.220 0');

  text('Persentase Kehadiran Tiap Siswa', 42, 638, size: 15, font: 'F2');
  fillRect(42, 604, 510, 26, '0.145 0.388 0.922');
  text('NO', 54, 613, size: 9, font: 'F2', color: '1 1 1');
  text('NAMA SISWA', 92, 613, size: 9, font: 'F2', color: '1 1 1');
  text('HADIR JP', 330, 613, size: 9, font: 'F2', color: '1 1 1');
  text('TOTAL JP', 410, 613, size: 9, font: 'F2', color: '1 1 1');
  text('PERSEN', 500, 613, size: 9, font: 'F2', color: '1 1 1');

  var y = 578.0;
  for (var index = 0; index < data.summaries.length; index++) {
    if (y < 92) break;
    final row = data.summaries[index];
    fillRect(42, y - 8, 510, 28, index.isEven ? '1 1 1' : '0.980 0.984 0.992');
    line(42, y - 8, 552, y - 8, '0.894 0.914 0.941');
    text('${index + 1}', 56, y, size: 10);
    text(row.name, 92, y, size: 10, font: 'F2');
    text('${row.presentSlots}', 342, y, size: 10, color: '0.047 0.545 0.310');
    text('${row.totalSlots}', 424, y, size: 10);
    text('${row.percent}%', 508, y, size: 10, font: 'F2');
    y -= 28;
  }

  line(42, 76, 552, 76, '0.894 0.914 0.941');
  text('Rangkuman dihitung dari 7 hari terakhir sejak laporan dibuat.', 42, 58, size: 9, color: '0.392 0.455 0.545');
  text('Dokumen dibuat otomatis oleh PresenSatu', 360, 58, size: 9, color: '0.392 0.455 0.545');
  return content.toString();
}

String _buildPdfDocument(List<String> streams) {
  final pageCount = streams.length;
  final f1Object = 3 + (pageCount * 2);
  final f2Object = f1Object + 1;
  final objects = <String>[
    '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
  ];

  final kids = <String>[];
  for (var index = 0; index < pageCount; index++) {
    kids.add('${3 + (index * 2)} 0 R');
  }
  objects.add(
    '2 0 obj\n<< /Type /Pages /Kids [${kids.join(' ')}] /Count $pageCount >>\nendobj\n',
  );

  for (var index = 0; index < pageCount; index++) {
    final pageObject = 3 + (index * 2);
    final contentObject = pageObject + 1;
    final stream = streams[index];
    objects
      ..add(
        '$pageObject 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 $f1Object 0 R /F2 $f2Object 0 R >> >> /Contents $contentObject 0 R >>\nendobj\n',
      )
      ..add(
        '$contentObject 0 obj\n<< /Length ${stream.length} >>\nstream\n$stream\nendstream\nendobj\n',
      );
  }

  objects
    ..add('$f1Object 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n')
    ..add('$f2Object 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n');

  final buffer = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  var offset = buffer.length;
  for (final object in objects) {
    offsets.add(offset);
    buffer.write(object);
    offset += object.length;
  }

  final xrefOffset = offset;
  buffer
    ..writeln('xref')
    ..writeln('0 ${objects.length + 1}')
    ..writeln('0000000000 65535 f ');
  for (var index = 1; index < offsets.length; index++) {
    buffer.writeln('${offsets[index].toString().padLeft(10, '0')} 00000 n ');
  }
  buffer
    ..writeln('trailer')
    ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>')
    ..writeln('startxref')
    ..writeln('$xrefOffset')
    ..writeln('%%EOF');
  return buffer.toString();
}

String _pdfEscape(String value) {
  final asciiValue = value.replaceAll(RegExp(r'[^\x20-\x7E]'), '?');
  return asciiValue
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)');
}

Future<String> _writeReportFile({
  required String fileName,
  required String content,
  required String mimeType,
}) async {
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('presensi_app/downloads');
      final result = await channel.invokeMethod<String>('saveReport', {
        'fileName': fileName,
        'content': content,
        'mimeType': mimeType,
      });
      if (result != null && result.isNotEmpty) return result;
    } catch (_) {
      // Fallback ke penulisan file langsung untuk emulator/perangkat lama.
    }
  }

  final candidates = <Directory>[
    Directory('/storage/emulated/0/Download'),
    Directory('/storage/emulated/0/Downloads'),
    Directory.systemTemp,
  ];

  Object? lastError;
  for (final directory in candidates) {
    try {
      if (!directory.existsSync()) continue;
      final file = File('${directory.path}/$fileName');
      final encoding = mimeType == 'application/pdf' ? latin1 : utf8;
      final savedFile =
          await file.writeAsString(content, encoding: encoding, flush: true);
      return savedFile.path;
    } catch (error) {
      lastError = error;
    }
  }

  throw Exception(lastError ?? 'Folder download tidak ditemukan');
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

Future<_RecapData> _loadRecapData(
  User user, {
  DateTime? date,
  bool fallbackAllSchedules = true,
}) async {
  final api = ApiService();
  final sourceDate = date ?? DateTime.now();
  final today = DateTime(sourceDate.year, sourceDate.month, sourceDate.day);
  final todayKey = _dateKey(today);
  final todayName = _indonesianDayName(today);

  final kelasResponse = await api.get('/api/kelas/');
  final kelasList = (kelasResponse as List)
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  Map<String, dynamic>? waliKelas;
  for (final item in kelasList) {
    if (_intFromJson(item['wali_kelas_id']) == user.id) {
      waliKelas = item;
      break;
    }
  }

  if (waliKelas == null) {
    return _RecapData.empty(
      date: today,
      dayName: todayName,
      message: 'Guru ini belum menjadi wali kelas.',
    );
  }

  final kelasId = _intFromJson(waliKelas['id']) ?? 0;
  final kelasName = waliKelas['nama_kelas']?.toString() ?? 'Kelas';
  final responses = await Future.wait([
    api.get('/api/siswa/kelas/$kelasId'),
    api.get('/api/jadwal/kelas/$kelasId'),
    api.get('/api/presensi/tanggal/$todayKey'),
    api.get('/api/mata-pelajaran/'),
  ]);

  final siswa = (responses[0] as List)
      .map((item) => _RecapStudent.fromJson(Map<String, dynamic>.from(item as Map)))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  final mapelById = <int, String>{};
  for (final raw in responses[3] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final id = _intFromJson(item['id']);
    if (id != null) mapelById[id] = item['nama_mapel']?.toString() ?? 'Mapel';
  }

  final presentKeys = <String>{};
  final presentScheduleIds = <int>{};
  for (final raw in responses[2] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final status = item['status']?.toString().trim().toLowerCase();
    if (status != 'hadir') continue;
    final siswaId = _intFromJson(item['siswa_id']);
    final jadwalId = _intFromJson(item['jadwal_id']);
    if (siswaId != null && jadwalId != null) {
      presentKeys.add('$siswaId:$jadwalId');
      presentScheduleIds.add(jadwalId);
    }
  }

  final allSchedules = (responses[1] as List)
      .map((item) => _RecapSchedule.fromJson(
            Map<String, dynamic>.from(item as Map),
            mapelById: mapelById,
          ))
      .where((item) => item.id != 0)
      .toList();

  final schedules = allSchedules
      .where(
        (item) =>
            _sameDayName(item.day, todayName) ||
            presentScheduleIds.contains(item.id),
      )
      .toList();

  if (schedules.isEmpty && fallbackAllSchedules) {
    schedules.addAll(allSchedules);
  }
  schedules.sort((a, b) => a.start.compareTo(b.start));

  final columns = <_RecapColumn>[];
  var jpNumber = 1;
  for (final schedule in schedules) {
    for (var index = 0; index < schedule.lessonHours; index++) {
      columns.add(
        _RecapColumn(
          number: jpNumber++,
          scheduleId: schedule.id,
          mapelName: schedule.mapelName,
        ),
      );
    }
  }

  final rows = siswa.map((student) {
    return _RecapRow(
      initials: _initials(student.name),
      name: student.name,
      avatarColor: _avatarColor(student.id),
      initialColor: _initialColor(student.id),
      logs: columns
          .map((column) => presentKeys.contains('${student.id}:${column.scheduleId}'))
          .toList(),
    );
  }).toList();

  return _RecapData(
    date: today,
    dayName: todayName,
    classId: kelasId,
    className: kelasName,
    students: siswa,
    columns: columns,
    rows: rows,
    message: null,
  );
}

class _RecapData {
  const _RecapData({
    required this.date,
    required this.dayName,
    required this.classId,
    required this.className,
    required this.students,
    required this.columns,
    required this.rows,
    required this.message,
  });

  final DateTime date;
  final String dayName;
  final int classId;
  final String className;
  final List<_RecapStudent> students;
  final List<_RecapColumn> columns;
  final List<_RecapRow> rows;
  final String? message;

  int get presentCount {
    if (columns.isEmpty) return 0;
    return rows.where((row) => row.logs.any((item) => item)).length;
  }

  int get absentCount {
    if (columns.isEmpty) return 0;
    return rows.where((row) => !row.logs.any((item) => item)).length;
  }

  factory _RecapData.empty({
    required DateTime date,
    required String dayName,
    required String message,
  }) {
    return _RecapData(
      date: date,
      dayName: dayName,
      classId: 0,
      className: '-',
      students: const [],
      columns: const [],
      rows: const [],
      message: message,
    );
  }
}

class _RecapStudent {
  const _RecapStudent({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory _RecapStudent.fromJson(Map<String, dynamic> json) {
    return _RecapStudent(
      id: _intFromJson(json['id']) ?? 0,
      name: json['nama']?.toString() ?? 'Siswa',
    );
  }
}

class _RecapSchedule {
  const _RecapSchedule({
    required this.id,
    required this.mapelName,
    required this.day,
    required this.start,
    required this.end,
  });

  final int id;
  final String mapelName;
  final String day;
  final String start;
  final String end;

  int get lessonHours {
    final startClock = _parseClock(start);
    final endClock = _parseClock(end);
    if (startClock == null || endClock == null) return 1;

    final startDate = DateTime(2026, 1, 1, startClock.$1, startClock.$2);
    final endDate = DateTime(2026, 1, 1, endClock.$1, endClock.$2);
    final minutes = endDate.difference(startDate).inMinutes;
    if (minutes <= 0) return 1;
    return (minutes / 40).round().clamp(1, 8).toInt();
  }

  factory _RecapSchedule.fromJson(
    Map<String, dynamic> json, {
    required Map<int, String> mapelById,
  }) {
    final mapelId = _intFromJson(json['mapel_id']) ?? 0;
    return _RecapSchedule(
      id: _intFromJson(json['id']) ?? 0,
      mapelName: mapelById[mapelId] ?? 'Mata Pelajaran',
      day: json['hari']?.toString() ?? '',
      start: json['jam_mulai']?.toString() ?? '',
      end: json['jam_selesai']?.toString() ?? '',
    );
  }
}

class _RecapColumn {
  const _RecapColumn({
    required this.number,
    required this.scheduleId,
    required this.mapelName,
  });

  final int number;
  final int scheduleId;
  final String mapelName;
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

class _WeeklyReportData {
  const _WeeklyReportData({
    required this.className,
    required this.startDate,
    required this.endDate,
    required this.generatedAt,
    required this.students,
    required this.dayReports,
    required this.summaries,
  });

  final String className;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime generatedAt;
  final List<_RecapStudent> students;
  final List<_WeeklyDayReport> dayReports;
  final List<_WeeklyStudentSummary> summaries;

  String get rangeLabel => '${_dateLabel(startDate)} - ${_dateLabel(endDate)}';

  int get totalLessonSlots => dayReports.fold<int>(
        0,
        (total, item) => total + item.columns.length,
      );

  int get averagePercent {
    if (summaries.isEmpty) return 0;
    final totalPercent = summaries.fold<int>(
      0,
      (total, item) => total + item.percent,
    );
    return (totalPercent / summaries.length).round();
  }
}

class _WeeklyDayReport {
  const _WeeklyDayReport({
    required this.date,
    required this.dayName,
    required this.columns,
    required this.rows,
  });

  final DateTime date;
  final String dayName;
  final List<_RecapColumn> columns;
  final List<_RecapRow> rows;
}

class _WeeklyStudentSummary {
  const _WeeklyStudentSummary({
    required this.name,
    required this.presentSlots,
    required this.totalSlots,
  });

  final String name;
  final int presentSlots;
  final int totalSlots;

  int get percent {
    if (totalSlots == 0) return 0;
    return ((presentSlots / totalSlots) * 100).round();
  }
}

class _GuruSchedule {
  const _GuruSchedule({
    required this.id,
    required this.kelasId,
    required this.subject,
    required this.room,
    required this.timeRange,
    required this.className,
    required this.day,
    required this.icon,
    required this.status,
  });

  final int id;
  final int kelasId;
  final String subject;
  final String room;
  final String timeRange;
  final String className;
  final String day;
  final IconData icon;
  final _ScheduleStatus status;

  factory _GuruSchedule.fromJson(
    Map<String, dynamic> json, {
    required Map<int, String> kelasById,
    required Map<int, String> mapelById,
  }) {
    final id = _intFromJson(json['id']) ?? 0;
    final kelasId = _intFromJson(json['kelas_id']) ?? 0;
    final mapelId = _intFromJson(json['mapel_id']) ?? 0;
    final jamMulai = json['jam_mulai']?.toString() ?? '';
    final jamSelesai = json['jam_selesai']?.toString() ?? '';
    return _GuruSchedule(
      id: id,
      kelasId: kelasId,
      subject: mapelById[mapelId] ?? 'Mata Pelajaran',
      room: json['ruang']?.toString() ?? 'Ruang kelas',
      timeRange: '$jamMulai - $jamSelesai',
      className: kelasById[kelasId] ?? 'Kelas',
      day: json['hari']?.toString() ?? '',
      icon: Icons.menu_book_rounded,
      status: _scheduleStatus(jamMulai, jamSelesai),
    );
  }
}

enum _ScheduleStatus { ongoing, upcoming }

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

String _firstName(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'Guru';
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.first;
}

String _teacherGreeting(String? jenisKelamin) {
  final normalized = jenisKelamin?.trim().toLowerCase();
  if (normalized == 'perempuan') return 'Ibu';
  return 'Pak';
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

String _indonesianDayName(DateTime date) {
  const days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  return days[date.weekday - 1];
}

bool _sameDayName(String left, String right) {
  return left.trim().toLowerCase() == right.trim().toLowerCase();
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _dateLabel(DateTime date) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MEI',
    'JUN',
    'JUL',
    'AGU',
    'SEP',
    'OKT',
    'NOV',
    'DES',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty);
  final letters = parts.take(2).map((item) => item[0].toUpperCase()).join();
  return letters.isEmpty ? 'S' : letters;
}

Color _avatarColor(int seed) {
  const colors = [
    Color(0xFFDCEBFF),
    Color(0xFFE6E8FF),
    Color(0xFFFFF3C4),
    Color(0xFFFFE1E7),
    Color(0xFFD1FAE5),
  ];
  return colors[seed.abs() % colors.length];
}

Color _initialColor(int seed) {
  const colors = [
    Color(0xFF2563EB),
    Color(0xFF4F46E5),
    Color(0xFFD97706),
    Color(0xFFE11D48),
    Color(0xFF059669),
  ];
  return colors[seed.abs() % colors.length];
}

_ScheduleStatus _scheduleStatus(String jamMulai, String jamSelesai) {
  final start = _parseClock(jamMulai);
  final end = _parseClock(jamSelesai);
  if (start == null || end == null) return _ScheduleStatus.upcoming;

  final now = DateTime.now();
  final startToday = DateTime(now.year, now.month, now.day, start.$1, start.$2);
  final endToday = DateTime(now.year, now.month, now.day, end.$1, end.$2);
  if (now.isAfter(startToday) && now.isBefore(endToday)) {
    return _ScheduleStatus.ongoing;
  }
  return _ScheduleStatus.upcoming;
}

(int, int)? _parseClock(String value) {
  final parts = value.trim().replaceAll('.', ':').split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return (hour, minute);
}

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
