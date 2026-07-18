import 'package:flutter/material.dart';

/// Tiny sparkline used inside metric cards. Hand-rolled with
/// Containers instead of a charting package — not worth the
/// dependency weight for 6-7 static bars.
class MiniBarChart extends StatelessWidget {
  final List<double> values; // 0.0 - 1.0
  final Color color;
  final double height;

  const MiniBarChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: FractionallySizedBox(
                heightFactor: v.clamp(0.05, 1.0),
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}