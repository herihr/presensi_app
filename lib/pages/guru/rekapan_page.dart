import 'package:flutter/material.dart';

class RekapanPage extends StatelessWidget {
  const RekapanPage({
    super.key,
    required this.title,
    required this.className,
  });

  final String title;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _RekapanHeader(
              title: title,
              className: className,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 22, 0, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x120B3558),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hari Ini - Senin',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF222B3A),
                            ),
                      ),
                      const SizedBox(height: 18),
                      const SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _AttendanceGrid(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RekapanHeader extends StatelessWidget {
  const _RekapanHeader({
    required this.title,
    required this.className,
  });

  final String title;
  final String className;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 46, 20, 30),
      decoration: const BoxDecoration(
        color: Color(0xFF1E88E5),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: Colors.white,
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kelas $className',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceGrid extends StatelessWidget {
  const _AttendanceGrid();

  static const _students = [
    _AttendanceRow(name: 'Andi Pratama', statuses: [true, true, true, true, true]),
    _AttendanceRow(name: 'Budi Santoso', statuses: [true, true, false, true, true]),
    _AttendanceRow(name: 'Citra Lestari', statuses: [true, true, true, true, false]),
  ];

  @override
  Widget build(BuildContext context) {
    const columnWidth = 44.0;
    const nameWidth = 144.0;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: nameWidth,
              child: Center(
                child: Text(
                  'Nama',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF222B3A),
                      ),
                ),
              ),
            ),
            ...List.generate(
              5,
              (index) => SizedBox(
                width: columnWidth,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF222B3A),
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._students.map(
          (student) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: nameWidth,
                  child: Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF222B3A),
                        ),
                  ),
                ),
                ...student.statuses.map(
                  (isPresent) => SizedBox(
                    width: columnWidth,
                    child: Center(
                      child: _StatusSquare(isPresent: isPresent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusSquare extends StatelessWidget {
  const _StatusSquare({
    required this.isPresent,
  });

  final bool isPresent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: isPresent ? const Color(0xFF4CAF50) : const Color(0xFFE93B3B),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _AttendanceRow {
  const _AttendanceRow({
    required this.name,
    required this.statuses,
  });

  final String name;
  final List<bool> statuses;
}
