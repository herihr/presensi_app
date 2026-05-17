part of '../../pages/guru/guru_page.dart';
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

