import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/ingestion_screen.dart';
import 'package:media_kit/media_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const OrasApp());
}

class OrasApp extends StatelessWidget {
  const OrasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORAS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeShell(),
      routes: {
        '/analysis': (context) => const IngestionScreen(),
      },
    );
  }
}