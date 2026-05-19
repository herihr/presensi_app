import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  static String _activeBaseUrl = Constants.baseUrl;
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
    final res = await _sendWithFallback(
      endpoint,
      (uri) => http.get(uri, headers: _headers),
    );
    return _decodeResponse(res);
  }

  Future<dynamic> post(String endpoint, Map data) async {
    final encodedBody = jsonEncode(data);
    final res = await _sendWithFallback(
      endpoint,
      (uri) => http.post(
        uri,
        headers: _headers,
        body: encodedBody,
      ),
    );
    return _decodeResponse(res);
  }

  Future<dynamic> put(String endpoint, Map data) async {
    final encodedBody = jsonEncode(data);
    final res = await _sendWithFallback(
      endpoint,
      (uri) => http.put(
        uri,
        headers: _headers,
        body: encodedBody,
      ),
    );
    return _decodeResponse(res);
  }

  Future<dynamic> delete(String endpoint) async {
    final res = await _sendWithFallback(
      endpoint,
      (uri) => http.delete(uri, headers: _headers),
    );
    return _decodeResponse(res);
  }

  Future<dynamic> uploadFile(
    String endpoint,
    String filePath, {
    String fieldName = 'file',
  }) async {
    final response = await _sendMultipartWithFallback(endpoint, () async {
      final file = await http.MultipartFile.fromPath(fieldName, filePath);
      return [file];
    });
    return _decodeResponse(response);
  }

  Future<dynamic> uploadBytes(
    String endpoint,
    List<int> bytes, {
    String fieldName = 'file',
    String fileName = 'photo.jpg',
  }) async {
    final response = await _sendMultipartWithFallback(endpoint, () async {
      return [
        http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
      ];
    });
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
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:image/')) {
      return path;
    }
    if (path.startsWith('/')) return '$_activeBaseUrl$path';
    return path;
  }

  Future<http.Response> _sendWithFallback(
    String endpoint,
    Future<http.Response> Function(Uri uri) send,
  ) async {
    Object? lastError;

    for (final baseUrl in _candidateBaseUrls()) {
      try {
        final response = await send(Uri.parse('$baseUrl$endpoint')).timeout(
          const Duration(seconds: 12),
        );
        _activeBaseUrl = baseUrl;
        return response;
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      } on HandshakeException catch (error) {
        lastError = error;
      }
    }

    throw Exception('Tidak bisa terhubung ke backend: $lastError');
  }

  Future<http.Response> _sendMultipartWithFallback(
    String endpoint,
    Future<List<http.MultipartFile>> Function() buildFiles,
  ) async {
    Object? lastError;

    for (final baseUrl in _candidateBaseUrls()) {
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl$endpoint'),
        );

        if (_accessToken != null) {
          request.headers['Authorization'] = 'Bearer $_accessToken';
        }

        request.files.addAll(await buildFiles());

        final streamed = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final response = await http.Response.fromStream(streamed);
        _activeBaseUrl = baseUrl;
        return response;
      } on SocketException catch (error) {
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      } on HandshakeException catch (error) {
        lastError = error;
      }
    }

    throw Exception('Tidak bisa terhubung ke backend: $lastError');
  }

  List<String> _candidateBaseUrls() {
    if (!Constants.enableBackendFallback) return [Constants.baseUrl];

    final urls = <String>[
      _activeBaseUrl,
      ...Constants.fallbackBaseUrls,
    ];
    return urls.toSet().toList();
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
