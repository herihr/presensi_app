class User {
  final int id;
  final String nama;
  final String role;

  User({
    required this.id,
    required this.nama,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      nama: json['nama'],
      role: json['role'],
    );
  }
}