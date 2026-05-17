part of '../../pages/guru/guru_page.dart';
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

