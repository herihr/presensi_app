class GuruModel {
  const GuruModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.nip,
    this.jenisKelamin,
    this.fotoUrl,
    this.mapelIds = const [],
    this.waliKelasId,
  });

  final int id;
  final String nama;
  final String email;
  final String nip;
  final String? jenisKelamin;
  final String? fotoUrl;
  final List<int> mapelIds;
  final int? waliKelasId;

  factory GuruModel.fromJson(Map<String, dynamic> json) {
    return GuruModel(
      id: _intFromJson(json['id']),
      nama: json['nama']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      nip: json['nip']?.toString() ?? '',
      jenisKelamin: json['jenis_kelamin']?.toString(),
      fotoUrl: json['foto_url']?.toString(),
      mapelIds: _intListFromJson(json['mapel_ids']),
      waliKelasId: _nullableIntFromJson(json['wali_kelas_id']),
    );
  }
}

List<int> _intListFromJson(dynamic value) {
  if (value is! List) return const [];
  return value.map(_nullableIntFromJson).whereType<int>().toList();
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
