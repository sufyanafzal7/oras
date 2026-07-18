import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/analysis_screen.dart';

void main() {
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
        '/analysis': (context) => const AnalysisScreen(),
      },
    );
  }
}