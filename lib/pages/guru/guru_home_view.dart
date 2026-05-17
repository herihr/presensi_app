part of 'guru_page.dart';

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
