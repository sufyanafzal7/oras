import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'mini_bar_chart.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final List<double> sparkline;
  final IconData? trailingIcon;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.sparkline,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      letterSpacing: 0.5)),
              if (trailingIcon != null)
                Icon(trailingIcon, size: 14, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          MiniBarChart(values: sparkline, color: accentColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}