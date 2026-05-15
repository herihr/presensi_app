import 'package:flutter/material.dart';

import 'pages/login_page.dart';

Future<void> main() async {

  // WAJIB untuk plugin/platform channel
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('FLUTTER SUDAH READY');

  runApp(
    const PresensiApp(),
  );
}

class PresensiApp extends StatelessWidget {
  const PresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Presensi App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF1F4F8),
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}