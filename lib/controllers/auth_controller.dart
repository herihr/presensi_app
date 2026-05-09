import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController {
  final AuthService _service = AuthService();

  Future<User?> login(String email, String password) {
    return _service.login(email, password);
  }

  void logout() {
    _service.logout();
  }
}
