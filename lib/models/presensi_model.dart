class Presensi {
  final int id;
  final int userId;
  final String waktu;

  Presensi({
    required this.id,
    required this.userId,
    required this.waktu,
  });

  factory Presensi.fromJson(Map<String, dynamic> json) {
    return Presensi(
      id: json['id'],
      userId: json['user_id'],
      waktu: json['waktu'],
    );
  }
}