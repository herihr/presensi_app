class JadwalModel {
  const JadwalModel({
    required this.id,
    required this.kelasId,
    required this.guruId,
    required this.mapelId,
    required this.hari,
    required this.jamMulai,
    required this.jamSelesai,
    this.jumlahJamPelajaran = 1,
  });

  final int id;
  final int kelasId;
  final int guruId;
  final int mapelId;
  final String hari;
  final String jamMulai;
  final String jamSelesai;
  final int jumlahJamPelajaran;

  factory JadwalModel.fromJson(Map<String, dynamic> json) {
    return JadwalModel(
      id: _intFromJson(json['id']),
      kelasId: _intFromJson(json['kelas_id']),
      guruId: _intFromJson(json['guru_id']),
      mapelId: _intFromJson(json['mapel_id']),
      hari: json['hari']?.toString() ?? '',
      jamMulai: json['jam_mulai']?.toString() ?? '',
      jamSelesai: json['jam_selesai']?.toString() ?? '',
      jumlahJamPelajaran: _intFromJson(json['jumlah_jam_pelajaran'] ?? 1),
    );
  }
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
