import 'dart:convert';

class User {
  final int id;
  final String nama;
  final String? jenisKelamin;
  final String email;
  final String? fotoUrl;
  final String role;
  final bool isWali;
  final bool isMapel;
  final String accessToken;
  final String tokenType;

  User({
    required this.id,
    required this.nama,
    this.jenisKelamin,
    required this.email,
    this.fotoUrl,
    required this.role,
    required this.isWali,
    required this.isMapel,
    required this.accessToken,
    required this.tokenType,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _intFromJson(json['id']),
      nama: json['nama']?.toString() ?? '',
      jenisKelamin: _nullableStringFromJson(json['jenis_kelamin']),
      email: json['email'] ?? '',
      fotoUrl: json['foto_url']?.toString(),
      role: json['role']?.toString() ?? '',
      isWali: json['is_wali'] ?? false,
      isMapel: json['is_mapel'] ?? false,
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
    );
  }

  factory User.fromLoginResponse(Map<String, dynamic> json) {
    final userJson = _mapFromJson(json['user'], fieldName: 'user');

    return User(
      id: _intFromJson(userJson['id']),
      nama: userJson['nama']?.toString() ?? '',
      jenisKelamin: _nullableStringFromJson(userJson['jenis_kelamin']),
      email: userJson['email']?.toString() ?? '',
      fotoUrl: userJson['foto_url']?.toString(),
      role: userJson['role']?.toString() ?? '',
      isWali: userJson['is_wali'] ?? false,
      isMapel: userJson['is_mapel'] ?? false,
      accessToken: json['access_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isGuru => role == 'guru';

  User copyWith({
    int? id,
    String? nama,
    String? jenisKelamin,
    String? email,
    String? fotoUrl,
    String? role,
    bool? isWali,
    bool? isMapel,
    String? accessToken,
    String? tokenType,
  }) {
    return User(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      role: role ?? this.role,
      isWali: isWali ?? this.isWali,
      isMapel: isMapel ?? this.isMapel,
      accessToken: accessToken ?? this.accessToken,
      tokenType: tokenType ?? this.tokenType,
    );
  }
}

String? _nullableStringFromJson(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _mapFromJson(dynamic value, {required String fieldName}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  }
  throw FormatException('Format $fieldName dari server tidak valid');
}

int _intFromJson(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
