part of 'guru_page.dart';
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

