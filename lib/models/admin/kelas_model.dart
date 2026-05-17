class KelasModel {
  const KelasModel({
    required this.id,
    required this.namaKelas,
    this.waliKelasId,
    this.waliKelasNama,
  });

  final int id;
  final String namaKelas;
  final int? waliKelasId;
  final String? waliKelasNama;

  factory KelasModel.fromJson(Map<String, dynamic> json) {
    return KelasModel(
      id: _intFromJson(json['id']),
      namaKelas: json['nama_kelas']?.toString() ?? '',
      waliKelasId: _nullableIntFromJson(json['wali_kelas_id']),
      waliKelasNama: json['wali_kelas_nama']?.toString(),
    );
  }
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableIntFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
