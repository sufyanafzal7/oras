import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/common/oras_app_bar.dart';
import '../widgets/common/oras_bottom_nav.dart';
import 'dashboard_screen.dart';
import 'placeholder_screen.dart';
import 'analysis_screen.dart';

/// Holds the persistent app bar + bottom nav, switching between
/// the four main tabs via IndexedStack so each tab keeps its
/// scroll position / state when you switch away and back.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    const AnalysisScreen(),
    PlaceholderScreen(title: 'AI Insight Engine', icon: Icons.insights_rounded),
    PlaceholderScreen(title: 'Reports', icon: Icons.description_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OrasAppBar(),
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: OrasBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}