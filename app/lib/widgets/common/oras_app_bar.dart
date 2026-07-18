import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class OrasAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OrasAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_hospital_rounded,
              color: AppColors.accentCyan,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'ORAS',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Icon(Icons.notifications_none_rounded,
              color: AppColors.textSecondary),
        ),
      ],
    );
  }
}