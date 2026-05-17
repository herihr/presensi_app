part of '../../pages/guru/guru_page.dart';
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

