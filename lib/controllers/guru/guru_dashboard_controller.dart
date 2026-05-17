import '../../models/auth/user_model.dart';

class GuruDashboardController {
  const GuruDashboardController(this.user);

  final User user;

  String get sapaan {
    final gender = user.jenisKelamin?.trim().toLowerCase();
    final prefix = gender == 'perempuan' ? 'Ibu' : 'Pak';
    final firstName = user.nama.trim().split(RegExp(r'\s+')).first;
    return 'Halo, $prefix $firstName';
  }
}
