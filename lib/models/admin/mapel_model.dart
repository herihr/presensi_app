class MapelModel {
  const MapelModel({
    required this.id,
    required this.namaMapel,
  });

  final int id;
  final String namaMapel;

  factory MapelModel.fromJson(Map<String, dynamic> json) {
    return MapelModel(
      id: _intFromJson(json['id']),
      namaMapel: json['nama_mapel']?.toString() ?? '',
    );
  }
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
