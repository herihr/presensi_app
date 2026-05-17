import '../models/auth/user_model.dart';
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

  Future<bool> requestPasswordReset(String email, String role) async {
    final res = await _api.post("/auth/forgot-password", {
      "email": email,
      "role": role,
    });

    if (res is Map) {
      return res['email_sent'] == true;
    }

    throw Exception('Response reset password tidak valid dari server');
  }

  Future<void> resetPassword({
    required String email,
    required String role,
    required String code,
    required String newPassword,
  }) async {
    await _api.post("/auth/reset-password", {
      "email": email,
      "role": role,
      "code": code,
      "new_password": newPassword,
    });
  }

  void logout() {
    ApiService.clearToken();
  }
}
