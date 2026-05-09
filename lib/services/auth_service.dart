import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<User?> login(String email, String password) async {
    final res = await _api.post("/auth/login", {
      "email": email,
      "password": password,
    });

    if (res is! Map) {
      throw Exception('Response login tidak valid dari server');
    }

    final user = User.fromLoginResponse(Map<String, dynamic>.from(res));
    ApiService.setToken(user.accessToken);
    return user;
  }

  void logout() {
    ApiService.clearToken();
  }
}
