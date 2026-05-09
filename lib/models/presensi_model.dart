class Presensi {
  final int id;
  final int siswaId;
  final int jadwalId;
  final int guruId;
  final String status;
  final String tanggal;
  final String jamPresensi;

  Presensi({
    required this.id,
    required this.siswaId,
    required this.jadwalId,
    required this.guruId,
    required this.status,
    required this.tanggal,
    required this.jamPresensi,
  });

  factory Presensi.fromJson(Map<String, dynamic> json) {
    return Presensi(
      id: json['id'],
      siswaId: json['siswa_id'],
      jadwalId: json['jadwal_id'],
      guruId: json['guru_id'],
      status: json['status'],
      tanggal: json['tanggal'],
      jamPresensi: json['jam_presensi'],
    );
  }
}
