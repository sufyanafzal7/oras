import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 3 — 7 stacked horizontal lanes (one per tool).
/// Each lane shows the fraction of total duration that tool was active.
/// Presence is estimated proportionally from framesDetected.
class ToolActivityGrid extends StatelessWidget {
  final AnalysisState state;
  const ToolActivityGrid({super.key, required this.state});

  static const _toolColors = [
    Color(0xFF4FC3F7), // grasper
    Color(0xFFE8447A), // bipolar
    Color(0xFF81C784), // hook
    Color(0xFFBA68C8), // scissors
    Color(0xFFFFB74D), // clipper
    Color(0xFF4DB6AC), // irrigator
    Color(0xFFFFD54F), // specimenbag
  ];

  String _fmt(double s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final tools   = state.toolsDetected;
    final total   = state.totalDuration;
    final fps     = state.fps;
    final totalSamples = (total * fps / 2).clamp(1.0, double.infinity);

    if (tools.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...kAllTools.map((toolName) {
            final result = tools.cast<ToolResult?>().firstWhere(
                  (t) => t?.tool == toolName,
              orElse: () => null,
            );
            final frames     = result?.framesDetected ?? 0;
            final activeFrac = (frames / totalSamples).clamp(0.0, 1.0);
            final colorIdx   = kAllTools.indexOf(toolName);
            final color      = _toolColors[colorIdx.clamp(0, _toolColors.length - 1)];
            final activeSeconds = activeFrac * total;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // Tool name label
                  SizedBox(
                    width: 88,
                    child: Text(toolName,
                        style: TextStyle(
                            color: result != null
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: result != null
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ),
                  // Activity bar
                  Expanded(
                    child: LayoutBuilder(builder: (_, c) {
                      return Tooltip(
                        message: result != null
                            ? '$toolName\n'
                            'Active: ~${_fmt(activeSeconds)} '
                            '(${(activeFrac * 100).toStringAsFixed(1)}%)\n'
                            'Frames detected: $frames'
                            : '$toolName — not detected',
                        textStyle: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 11),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Stack(
                          children: [
                            // Track
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            // Fill
                            if (activeFrac > 0)
                              Container(
                                height: 14,
                                width: c.maxWidth * activeFrac,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 8),
                  // Percentage label
                  SizedBox(
                    width: 40,
                    child: Text(
                      result != null
                          ? '${(activeFrac * 100).toStringAsFixed(1)}%'
                          : '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: result != null ? color : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          // Time axis
          Row(
            children: [
              const SizedBox(width: 88),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _tick('0:00'),
                    _tick(_fmt(total / 2)),
                    _tick(_fmt(total)),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tick(String label) => Text(label,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 9));
}