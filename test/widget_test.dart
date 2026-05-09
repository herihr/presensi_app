import 'package:flutter_test/flutter_test.dart';
import 'package:presensi_app/main.dart';

void main() {
  testWidgets('shows login page', (tester) async {
    await tester.pumpWidget(const PresensiApp());

    expect(find.text('Masuk Akun'), findsOneWidget);
    expect(find.text('Guru'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });
}
