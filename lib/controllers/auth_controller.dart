import '../models/auth/user_model.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService _service = AuthService();

  Future<User?> login(String email, String password) {
    return _service.login(email, password);
  }

  Future<bool> requestPasswordReset(String email, String role) {
    return _service.requestPasswordReset(email, role);
  }

  Future<void> resetPassword({
    required String email,
    required String role,
    required String code,
    required String newPassword,
  }) {
    return _service.resetPassword(
      email: email,
      role: role,
      code: code,
      newPassword: newPassword,
    );
  }

  void logout() {
    _service.logout();
  }
}
