import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final ApiService _api = ApiService();
  late Future<_DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_DashboardStats> _loadStats() async {
    final responses = await Future.wait([
      _api.get('/api/guru/'),
      _api.get('/api/siswa/'),
      _api.get('/api/presensi/'),
    ]);

    final presensi = (responses[2] as List)
        .map((item) => _PresensiItem.fromJson(item as Map<String, dynamic>))
        .toList();

    return _DashboardStats.fromData(
      totalGuru: (responses[0] as List).length,
      totalSiswa: (responses[1] as List).length,
      presensi: presensi,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _loadStats();
    });
    try {
      await _statsFuture;
    } catch (_) {
      // Error tetap ditampilkan oleh FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data ?? _DashboardStats.empty();
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Statistik',
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF191B23),
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Data kehadiran sekolah hari ini, ${_getCurrentDate()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF434655),
                            ),
                      ),
                      if (snapshot.hasError) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(
                          message: snapshot.error
                              .toString()
                              .replaceFirst('Exception: ', ''),
                        ),
                      ],
                      const SizedBox(height: 24),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1 / 1.2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(
                            icon: Icons.group_outlined,
                            iconColor: const Color(0xFF2563EB),
                            backgroundColor:
                                const Color(0xFF2563EB).withOpacity(0.1),
                            label: 'TOTAL SISWA',
                            value: isLoading ? '...' : _formatNumber(stats.totalSiswa),
                            trend: 'Basis Data',
                            trendColor: const Color(0xFF2563EB),
                            trendIcon: Icons.storage_rounded,
                          ),
                          _StatCard(
                            icon: Icons.school_outlined,
                            iconColor: const Color(0xFF943700),
                            backgroundColor:
                                const Color(0xFF943700).withOpacity(0.1),
                            label: 'TOTAL GURU',
                            value: isLoading ? '...' : _formatNumber(stats.totalGuru),
                            trend: 'Basis Data',
                            trendColor: const Color(0xFF943700),
                            trendIcon: Icons.storage_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _AttendanceCard(
                        percentage: stats.monthlyAttendancePercentage,
                        presentCount: stats.monthlyPresent,
                        totalCount: stats.monthlyTotal,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 24),
                      const SizedBox(height: 12),
                      _AttendanceTrendChart(
                        data: stats.lastSevenDays,
                        labels: stats.lastSevenDayLabels,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Insight Mingguan',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF191B23),
                            ),
                      ),
                      const SizedBox(height: 12),
                      _InsightCard(
                        icon: Icons.fact_check_rounded,
                        title: 'Presensi Bulan Ini',
                        description:
                            '${stats.monthlyPresent} dari ${stats.monthlyTotal} catatan presensi berstatus hadir.',
                        iconColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF3F3FE),
                      ),
                      const SizedBox(height: 12),
                      _InsightCard(
                        icon: Icons.show_chart_rounded,
                        title: 'Tren 7 Hari',
                        description:
                            'Rata-rata 7 hari terakhir adalah ${stats.weeklyAverageText}.',
                        iconColor: const Color(0xFF943700),
                        backgroundColor: const Color(0xFFF3F3FE),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _formatNumber(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < text.length; index++) {
      final remaining = text.length - index;
      buffer.write(text[index]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final String value;
  final String trend;
  final Color trendColor;
  final IconData trendIcon;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.value,
    required this.trend,
    required this.trendColor,
    required this.trendIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFC3C6D7).withOpacity(0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF434655),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Icon(trendIcon, size: 16, color: trendColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    trend,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: trendColor,
                    ),
                    overflow: TextOverflow.ellipsis,
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

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.percentage,
    required this.presentCount,
    required this.totalCount,
    required this.isLoading,
  });

  final double percentage;
  final int presentCount;
  final int totalCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RATA-RATA KEHADIRAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  Icon(
                    Icons.analytics_outlined,
                    color: Colors.white.withOpacity(0.8),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    isLoading ? '...' : '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    totalCount == 0 ? 'Belum ada data' : 'Bulan ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E40AF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth *
                              (percentage / 100).clamp(0, 1).toDouble(),
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$presentCount hadir dari $totalCount catatan presensi',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceTrendChart extends StatelessWidget {
  const _AttendanceTrendChart({
    required this.data,
    required this.labels,
  });

  final List<double> data;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final maxValue = 100.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFFC3C6D7).withOpacity(0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tren Kehadiran',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF191B23),
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text(
                      '7 HARI TERAKHIR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_more,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                data.length,
                (index) {
                  final value = data[index];
                  final height = (value / maxValue) * 150;
                  final highest = data.isEmpty
                      ? 0
                      : data.reduce((current, next) => current > next ? current : next);
                  final isHighest = value > 0 && value == highest;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isHighest) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF191B23),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${value.round()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      GestureDetector(
                        onTap: () {},
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            width: 32,
                            height: height,
                            decoration: BoxDecoration(
                              color: isHighest
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFF0F0FB),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isHighest ? FontWeight.w700 : FontWeight.w500,
                          color: isHighest
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF737686),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color backgroundColor;

  const _InsightCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: const Color(0xFFC3C6D7).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191B23),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF434655),
                    height: 1.4,
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

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.totalGuru,
    required this.totalSiswa,
    required this.monthlyPresent,
    required this.monthlyTotal,
    required this.lastSevenDays,
    required this.lastSevenDayLabels,
  });

  final int totalGuru;
  final int totalSiswa;
  final int monthlyPresent;
  final int monthlyTotal;
  final List<double> lastSevenDays;
  final List<String> lastSevenDayLabels;

  double get monthlyAttendancePercentage {
    if (monthlyTotal == 0) return 0;
    return (monthlyPresent / monthlyTotal) * 100;
  }

  String get weeklyAverageText {
    if (lastSevenDays.isEmpty) return '0.0%';
    final total = lastSevenDays.fold<double>(0, (sum, item) => sum + item);
    return '${(total / lastSevenDays.length).toStringAsFixed(1)}%';
  }

  factory _DashboardStats.empty() {
    return _DashboardStats(
      totalGuru: 0,
      totalSiswa: 0,
      monthlyPresent: 0,
      monthlyTotal: 0,
      lastSevenDays: List<double>.filled(7, 0),
      lastSevenDayLabels: _lastSevenDateLabels(DateTime.now()),
    );
  }

  factory _DashboardStats.fromData({
    required int totalGuru,
    required int totalSiswa,
    required List<_PresensiItem> presensi,
  }) {
    final now = DateTime.now();
    final monthly = presensi.where((item) {
      final date = item.date;
      return date != null && date.year == now.year && date.month == now.month;
    }).toList();

    final monthlyPresent = monthly.where((item) => item.isPresent).length;
    final lastSevenDays = <double>[];
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    for (var offset = 0; offset < 7; offset++) {
      final day = startDate.add(Duration(days: offset));
      final dayItems = presensi.where((item) {
        final date = item.date;
        return date != null &&
            date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList();

      if (dayItems.isEmpty) {
        lastSevenDays.add(0);
      } else {
        final present = dayItems.where((item) => item.isPresent).length;
        lastSevenDays.add((present / dayItems.length) * 100);
      }
    }

    return _DashboardStats(
      totalGuru: totalGuru,
      totalSiswa: totalSiswa,
      monthlyPresent: monthlyPresent,
      monthlyTotal: monthly.length,
      lastSevenDays: lastSevenDays,
      lastSevenDayLabels: _lastSevenDateLabels(now),
    );
  }
}

class _PresensiItem {
  const _PresensiItem({
    required this.status,
    required this.tanggal,
  });

  final String status;
  final String tanggal;

  bool get isPresent => status.toLowerCase() == 'hadir';

  DateTime? get date => DateTime.tryParse(tanggal);

  factory _PresensiItem.fromJson(Map<String, dynamic> json) {
    return _PresensiItem(
      status: json['status']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
    );
  }
}

List<String> _lastSevenDateLabels(DateTime now) {
  const labels = ['MIN', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB'];
  final startDate =
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  return List.generate(7, (index) {
    final day = startDate.add(Duration(days: index));
    return labels[day.weekday % 7];
  });
}
