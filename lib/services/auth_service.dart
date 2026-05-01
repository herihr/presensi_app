import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<User?> login(String email, String password) async {
    final res = await _api.post("/auth/login", {
      "email": email,
      "password": password,
    });

    final userJson = res['user']; // 🔥 ambil bagian user saja
    return User.fromJson(userJson);
  }
}
