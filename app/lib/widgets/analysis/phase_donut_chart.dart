import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 4 — Donut chart of phase time distribution.
class PhaseDonutChart extends StatefulWidget {
  final AnalysisState state;
  const PhaseDonutChart({super.key, required this.state});

  @override
  State<PhaseDonutChart> createState() => _PhaseDonutChartState();
}

class _PhaseDonutChartState extends State<PhaseDonutChart> {
  String? _hovered;

  @override
  Widget build(BuildContext context) {
    final pcts = widget.state.phasePercentages;
    if (pcts.isEmpty) return const SizedBox.shrink();

    final entries = pcts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
          const Text('Phase Distribution',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('% of total procedure time',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _DonutPainter(
                      entries: entries,
                      hovered: _hovered,
                    ),
                  ),
                  // Center label
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _hovered != null
                            ? '${pcts[_hovered]!.toStringAsFixed(1)}%'
                            : '${entries.length}',
                        style: TextStyle(
                            color: _hovered != null
                                ? (kPhaseColors[_hovered] ??
                                AppColors.accentCyan)
                                : AppColors.textPrimary,
                            fontSize: _hovered != null ? 22 : 26,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        _hovered != null ? _hovered! : 'phases',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          ...entries.map((e) {
            final col = kPhaseColors[e.key] ?? const Color(0xFF5A6A7A);
            final isHl = _hovered == e.key;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = e.key),
              onExit:  (_) => setState(() => _hovered = null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isHl
                      ? col.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: col,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            color: isHl
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 11)),
                  ),
                  Text('${e.value.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: isHl ? col : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<String, double>> entries;
  final String? hovered;

  _DonutPainter({required this.entries, this.hovered});

  @override
  void paint(Canvas canvas, Size size) {
    final cx    = size.width / 2;
    final cy    = size.height / 2;
    final outer = size.width / 2 - 4;
    final inner = outer * 0.58;
    double startAngle = -math.pi / 2;
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    for (final entry in entries) {
      final sweep = (entry.value / total) * 2 * math.pi;
      final col   = kPhaseColors[entry.key] ?? const Color(0xFF5A6A7A);
      final isHl  = hovered == entry.key;
      final r     = isHl ? outer + 6 : outer;

      final paint = Paint()
        ..color     = col.withValues(alpha: isHl ? 1.0 : 0.8)
        ..style     = PaintingStyle.stroke
        ..strokeWidth = (r - inner)
        ..strokeCap   = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(
            center: Offset(cx, cy), radius: (r + inner) / 2),
        startAngle,
        sweep - 0.03,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.hovered != hovered;
}