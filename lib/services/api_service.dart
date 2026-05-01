import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  final String baseUrl = Constants.baseUrl; // emulator

  Future<dynamic> get(String endpoint) async {
    final res = await http.get(Uri.parse("$baseUrl$endpoint"));
    return jsonDecode(res.body);
  }

  Future<dynamic> post(String endpoint, Map data) async {
    final res = await http.post(
      Uri.parse("$baseUrl$endpoint"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }
}