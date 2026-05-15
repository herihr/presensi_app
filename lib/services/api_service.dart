import 'dart:convert';
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
