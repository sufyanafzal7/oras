import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 6 — One card per detected phase with timing + tool context.
class PhaseDetailCards extends StatelessWidget {
  final AnalysisState state;
  const PhaseDetailCards({super.key, required this.state});

  String _fmt(double s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final durations = state.phaseDurations;
    final pcts      = state.phasePercentages;
    final toolMap   = state.phaseToolMap;
    final total     = state.totalDuration;

    if (durations.isEmpty) return const SizedBox.shrink();

    // Group consecutive segments by phase for start/end per occurrence
    final occurrences = <_PhaseOccurrence>[];
    for (final seg in state.phaseTimeline) {
      if (occurrences.isNotEmpty &&
          occurrences.last.phase == seg.phase &&
          (seg.startTime - occurrences.last.endTime).abs() < 1.0) {
        // Merge adjacent same-phase segments
        occurrences.last = _PhaseOccurrence(
          phase:     seg.phase,
          startTime: occurrences.last.startTime,
          endTime:   seg.endTime,
        );
      } else {
        occurrences.add(_PhaseOccurrence(
          phase:     seg.phase,
          startTime: seg.startTime,
          endTime:   seg.endTime,
        ));
      }
    }

    // One card per unique phase
    final uniquePhases = durations.keys.toList()
      ..sort((a, b) =>
          (durations[b] ?? 0).compareTo(durations[a] ?? 0));

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 3 :
      constraints.maxWidth > 450 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: uniquePhases.map((phase) {
          final col       = kPhaseColors[phase] ?? const Color(0xFF5A6A7A);
          final dur       = durations[phase] ?? 0;
          final pct       = pcts[phase] ?? 0;
          final tools     = toolMap[phase] ?? {};
          final firstOcc  = occurrences.firstWhere(
                  (o) => o.phase == phase,
              orElse: () =>
                  _PhaseOccurrence(phase: phase, startTime: 0, endTime: 0));

          // Progress bar fill
          final frac = total > 0 ? dur / total : 0.0;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: col.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phase name + color dot
                Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: col, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(phase,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: col,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                // Duration progress bar
                Stack(children: [
                  Container(
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(2))),
                  FractionallySizedBox(
                    widthFactor: frac.clamp(0.0, 1.0),
                    child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                            color: col,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                ]),
                const SizedBox(height: 8),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _stat('Duration', _fmt(dur)),
                    _stat('Share', '${pct.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 6),
                _stat('First seen', '${_fmt(firstOcc.startTime)} → ${_fmt(firstOcc.endTime)}'),
                const Spacer(),
                // Tools present
                if (tools.isNotEmpty) ...[
                  const Text('Instruments present',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tools.map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: col.withValues(alpha: 0.3)),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              color: col, fontSize: 9)),
                    )).toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textMuted, fontSize: 9)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _PhaseOccurrence {
  final String phase;
  final double startTime;
  final double endTime;
  _PhaseOccurrence(
      {required this.phase,
        required this.startTime,
        required this.endTime});
}