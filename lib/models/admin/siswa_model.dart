class SiswaModel {
  const SiswaModel({
    required this.id,
    required this.nama,
    required this.nis,
    required this.kelasId,
    required this.alamat,
    this.jenisKelamin,
    this.fotoUrl,
    this.embeddingStatus,
    this.namaKelas,
  });

  final int id;
  final String nama;
  final String nis;
  final int kelasId;
  final String alamat;
  final String? jenisKelamin;
  final String? fotoUrl;
  final String? embeddingStatus;
  final String? namaKelas;

  factory SiswaModel.fromJson(Map<String, dynamic> json) {
    return SiswaModel(
      id: _intFromJson(json['id']),
      nama: json['nama']?.toString() ?? '',
      nis: json['nis']?.toString() ?? '',
      kelasId: _intFromJson(json['kelas_id']),
      alamat: json['alamat']?.toString() ?? '',
      jenisKelamin: json['jenis_kelamin']?.toString(),
      fotoUrl: json['foto_url']?.toString(),
      embeddingStatus: json['embedding_status']?.toString(),
      namaKelas: json['nama_kelas']?.toString(),
    );
  }
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
