import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  final String baseUrl = Constants.baseUrl; // emulator
  static String? _accessToken;

  static void setToken(String token) {
    _accessToken = token;
  }

  static void clearToken() {
    _accessToken = null;
  }

  Map<String, String> get _headers {
    return {
      "Content-Type": "application/json",
      if (_accessToken != null) "Authorization": "Bearer $_accessToken",
    };
  }

  Future<dynamic> get(String endpoint) async {
    final res = await http.get(
      Uri.parse("$baseUrl$endpoint"),
      headers: _headers,
    );
    return _decodeResponse(res);
  }

  Future<dynamic> post(String endpoint, Map data) async {
    final res = await http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decodeResponse(res);
  }

  Future<dynamic> put(String endpoint, Map data) async {
    final res = await http.put(
      Uri.parse("$baseUrl$endpoint"),
      headers: _headers,
      body: jsonEncode(data),
    );
    return _decodeResponse(res);
  }

  Future<dynamic> delete(String endpoint) async {
    final res = await http.delete(
      Uri.parse("$baseUrl$endpoint"),
      headers: _headers,
    );
    return _decodeResponse(res);
  }

  Future<dynamic> uploadFile(
    String endpoint,
    String filePath, {
    String fieldName = 'file',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );

    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    request.files.add(
      await http.MultipartFile.fromPath(fieldName, filePath),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Future<dynamic> uploadBytes(
    String endpoint,
    List<int> bytes, {
    String fieldName = 'file',
    String fileName = 'photo.jpg',
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );

    if (_accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Future<String?> uploadPhotoIfLocal(String? path, String category) async {
    if (path == null || path.isEmpty) return path;
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('/uploads/')) {
      return path;
    }
    if (path.startsWith('data:image/')) {
      final commaIndex = path.indexOf(',');
      if (commaIndex == -1) return path;
      final header = path.substring(0, commaIndex).toLowerCase();
      final extension = header.contains('png')
          ? 'png'
          : header.contains('webp')
              ? 'webp'
              : 'jpg';
      final response = await uploadBytes(
        '/api/uploads/$category',
        base64Decode(path.substring(commaIndex + 1)),
        fileName: '$category-profile.$extension',
      );
      if (response is Map) {
        return response['foto_url']?.toString() ?? response['url']?.toString();
      }
      return path;
    }
    if (!File(path).existsSync()) return path;

    final response = await uploadFile('/api/uploads/$category', path);
    if (response is Map) {
      return response['foto_url']?.toString() ?? response['url']?.toString();
    }
    return path;
  }

  static String resolveMediaUrl(String? path) {
    return Constants.mediaUrl(path);
  }

  dynamic _decodeResponse(http.Response res) {
    final body = _tryDecodeJson(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }

    final detail = body is Map ? body['detail'] : res.reasonPhrase;
    final message = detail ?? body ?? 'Request gagal';
    throw Exception('HTTP ${res.statusCode}: $message');
  }

  dynamic _tryDecodeJson(String body) {
    if (body.isEmpty) return null;

    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }
}
