part of '../../pages/guru/guru_page.dart';
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

