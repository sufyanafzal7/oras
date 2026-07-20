import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 9 — Derived workflow efficiency and complexity metrics.
class EfficiencyMetrics extends StatelessWidget {
  final AnalysisState state;
  const EfficiencyMetrics({super.key, required this.state});

  String _fmt(double s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final longest       = state.longestPhase;
    final shortest      = state.shortestPhase;
    final total         = state.totalDuration;
    final transitions   = state.transitionCount;
    final diversity     = state.toolDiversityScore;
    final durations     = state.phaseDurations;

    if (total <= 0) return const SizedBox.shrink();

    // ── Derived metrics ──────────────────────────────────────────────────────
    // Phase balance score: 100% = all phases equal duration, 0% = one phase dominates
    double balanceScore = 0.0;
    if (durations.isNotEmpty) {
      final ideal   = total / durations.length;
      final sumDev  = durations.values
          .fold<double>(0, (s, d) => s + (d - ideal).abs());
      balanceScore = ((1.0 - (sumDev / (total * durations.length))) * 100)
          .clamp(0.0, 100.0);
    }

    // Instrument diversity score out of 7
    final diversityPct = (diversity / kAllTools.length) * 100;

    // Avg phase duration
    final avgPhaseDur = durations.isNotEmpty
        ? durations.values.fold<double>(0, (s, d) => s + d) /
        durations.length
        : 0.0;

    // Phase complexity = transitions per minute
    final complexityPerMin = total > 0
        ? (transitions / (total / 60)).toStringAsFixed(1)
        : '0.0';

    final metrics = [
      _MetricData(
        label:    'LONGEST PHASE',
        value:    longest != null ? _fmt(longest.duration) : '—',
        sub:      longest?.phase ?? '',
        color:    longest != null
            ? (kPhaseColors[longest.phase] ?? AppColors.accentCyan)
            : AppColors.textMuted,
        icon:     Icons.expand_outlined,
        progress: longest != null && total > 0
            ? longest.duration / total
            : 0.0,
      ),
      _MetricData(
        label:    'SHORTEST PHASE',
        value:    shortest != null ? _fmt(shortest.duration) : '—',
        sub:      shortest?.phase ?? '',
        color:    shortest != null
            ? (kPhaseColors[shortest.phase] ?? AppColors.accentAmber)
            : AppColors.textMuted,
        icon:     Icons.compress_outlined,
        progress: shortest != null && total > 0
            ? shortest.duration / total
            : 0.0,
      ),
      _MetricData(
        label:    'AVG PHASE DURATION',
        value:    _fmt(avgPhaseDur),
        sub:      'across ${durations.length} phases',
        color:    AppColors.accentCyan,
        icon:     Icons.timer_outlined,
        progress: total > 0 ? avgPhaseDur / total : 0.0,
      ),
      _MetricData(
        label:    'PHASE TRANSITIONS',
        value:    '$transitions',
        sub:      '$complexityPerMin / min complexity',
        color:    AppColors.accentAmber,
        icon:     Icons.swap_horiz_rounded,
        progress: (transitions / 20.0).clamp(0.0, 1.0),
      ),
      _MetricData(
        label:    'PHASE BALANCE',
        value:    '${balanceScore.toStringAsFixed(1)}%',
        sub:      balanceScore > 60
            ? 'Well balanced'
            : 'Dominated by one phase',
        color:    balanceScore > 60
            ? AppColors.accentGreen
            : AppColors.accentAmber,
        icon:     Icons.balance_rounded,
        progress: balanceScore / 100,
      ),
      _MetricData(
        label:    'INSTRUMENT COVERAGE',
        value:    '$diversity / ${kAllTools.length}',
        sub:      '${diversityPct.toStringAsFixed(0)}% of kit used',
        color:    diversityPct > 60
            ? AppColors.accentGreen
            : AppColors.accentCyan,
        icon:     Icons.hardware_outlined,
        progress: diversityPct / 100,
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 3 :
      constraints.maxWidth > 450 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.0,
        children: metrics.map((m) => _buildCard(m)).toList(),
      );
    });
  }

  Widget _buildCard(_MetricData m) {
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
          Row(children: [
            Icon(m.icon, size: 14, color: m.color),
            const SizedBox(width: 6),
            Text(m.label,
                style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 8),
          Text(m.value,
              style: TextStyle(
                  color: m.color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(m.sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 9)),
          const Spacer(),
          // Mini progress bar
          Stack(children: [
            Container(
                height: 3,
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(2))),
            FractionallySizedBox(
              widthFactor: m.progress.clamp(0.0, 1.0),
              child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                      color: m.color,
                      borderRadius: BorderRadius.circular(2))),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label, value, sub;
  final Color  color;
  final IconData icon;
  final double progress;
  const _MetricData({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
    required this.progress,
  });
}