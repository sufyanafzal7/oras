import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 2 — Horizontal Gantt bar showing all phases across total duration.
/// Tapping a segment shows a tooltip with exact timestamps.
class GanttTimeline extends StatefulWidget {
  final AnalysisState state;
  const GanttTimeline({super.key, required this.state});

  @override
  State<GanttTimeline> createState() => _GanttTimelineState();
}

class _GanttTimelineState extends State<GanttTimeline> {
  int? _hovered;

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final segs     = widget.state.phaseTimeline;
    final total    = widget.state.totalDuration;
    if (segs.isEmpty || total <= 0) return const SizedBox.shrink();

    // Unique phases for legend
    final seen   = <String>{};
    final legend = segs.where((s) => seen.add(s.phase)).toList();

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
          // ── Gantt bar ──────────────────────────────────────────────────────
          LayoutBuilder(builder: (_, c) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bar
                SizedBox(
                  height: 36,
                  child: Stack(
                    children: [
                      // Background track
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      // Phase segments
                      ...segs.asMap().entries.map((e) {
                        final i   = e.key;
                        final seg = e.value;
                        final x1  = (seg.startTime / total) * c.maxWidth;
                        final w   = ((seg.endTime - seg.startTime) / total) *
                            c.maxWidth;
                        final col = kPhaseColors[seg.phase] ??
                            const Color(0xFF5A6A7A);
                        final hl  = _hovered == i;
                        return Positioned(
                          left: x1,
                          width: w.clamp(2.0, double.infinity),
                          top:    hl ? 0 : 4,
                          bottom: hl ? 0 : 4,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            onEnter: (_) =>
                                setState(() => _hovered = i),
                            onExit:  (_) =>
                                setState(() => _hovered = null),
                            child: Tooltip(
                              message:
                              '${seg.phase}\n'
                                  '${_fmt(seg.startTime)} → ${_fmt(seg.endTime)}'
                                  '  (${_fmt(seg.duration)})',
                              preferBelow: false,
                              textStyle: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: AnimatedContainer(
                                duration:
                                const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: col.withValues(
                                      alpha: hl ? 1.0 : 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Time axis ticks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _tick('0:00'),
                    _tick(_fmt(total / 4)),
                    _tick(_fmt(total / 2)),
                    _tick(_fmt(total * 3 / 4)),
                    _tick(_fmt(total)),
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 14),
          // ── Legend ─────────────────────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: legend.map((seg) {
              final col = kPhaseColors[seg.phase] ??
                  const Color(0xFF5A6A7A);
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: col, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 5),
                Text(seg.phase,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _tick(String label) => Text(label,
      style: const TextStyle(color: AppColors.textMuted, fontSize: 9));
}