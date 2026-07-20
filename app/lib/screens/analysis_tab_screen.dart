import 'package:flutter/material.dart';
import '../services/analysis_state.dart';
import '../theme/app_colors.dart';
import '../widgets/analysis/summary_strip.dart';
import '../widgets/analysis/gantt_timeline.dart';
import '../widgets/analysis/tool_activity_grid.dart';
import '../widgets/analysis/phase_donut_chart.dart';
import '../widgets/analysis/tool_bar_chart.dart';
import '../widgets/analysis/phase_detail_cards.dart';
import '../widgets/analysis/tool_detail_cards.dart';
import '../widgets/analysis/cooccurrence_matrix.dart';
import '../widgets/analysis/efficiency_metrics.dart';

class AnalysisTabScreen extends StatefulWidget {
  const AnalysisTabScreen({super.key});

  @override
  State<AnalysisTabScreen> createState() => _AnalysisTabScreenState();
}

class _AnalysisTabScreenState extends State<AnalysisTabScreen> {
  @override
  void initState() {
    super.initState();
    AnalysisState.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AnalysisState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AnalysisState.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: state.hasResult
                ? _buildContent(state)
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 52,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded,
              color: AppColors.accentCyan, size: 18),
          const SizedBox(width: 8),
          const Text('Deep Analysis',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          const Text('Procedure Intelligence Report',
              style:
              TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          if (AnalysisState.instance.hasResult)
            TextButton.icon(
              onPressed: () => AnalysisState.instance.clear(),
              icon: const Icon(Icons.clear_rounded,
                  size: 14, color: AppColors.textMuted),
              label: const Text('Clear',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4)),
            ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.insights_rounded,
                color: AppColors.accentCyan, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No analysis loaded',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Upload and analyze a video in the Upload tab\nto see the full procedure intelligence report here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Main content — responsive layout ─────────────────────────────────────
  Widget _buildContent(AnalysisState state) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1 — Summary strip
            SummaryStrip(state: state),
            const SizedBox(height: 20),

            // Section 2 — Gantt phase timeline
            _sectionHeader('PHASE TIMELINE',
                'When each surgical phase occurred across the procedure'),
            const SizedBox(height: 10),
            GanttTimeline(state: state),
            const SizedBox(height: 20),

            // Section 3 — Tool activity grid
            _sectionHeader('TOOL ACTIVITY',
                'Instrument presence across the procedure duration'),
            const SizedBox(height: 10),
            ToolActivityGrid(state: state),
            const SizedBox(height: 20),

            // Section 4 & 5 — Donut + bar chart side by side on wide screens
            _sectionHeader('DISTRIBUTION',
                'Relative time per phase and usage per instrument'),
            const SizedBox(height: 10),
            isWide
                ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PhaseDonutChart(state: state)),
                const SizedBox(width: 12),
                Expanded(child: ToolBarChart(state: state)),
              ],
            )
                : Column(children: [
              PhaseDonutChart(state: state),
              const SizedBox(height: 12),
              ToolBarChart(state: state),
            ]),
            const SizedBox(height: 20),

            // Section 6 — Per-phase detail cards
            _sectionHeader('PHASE BREAKDOWN',
                'Individual analysis for each detected surgical phase'),
            const SizedBox(height: 10),
            PhaseDetailCards(state: state),
            const SizedBox(height: 20),

            // Section 7 — Per-tool detail cards
            _sectionHeader('INSTRUMENT BREAKDOWN',
                'Individual analysis for each detected surgical instrument'),
            const SizedBox(height: 10),
            ToolDetailCards(state: state),
            const SizedBox(height: 20),

            // Section 8 — Co-occurrence matrix
            _sectionHeader('PHASE–INSTRUMENT MATRIX',
                'Which instruments were active during each surgical phase'),
            const SizedBox(height: 10),
            CooccurrenceMatrix(state: state),
            const SizedBox(height: 20),

            // Section 9 — Efficiency metrics
            _sectionHeader('WORKFLOW METRICS',
                'Derived efficiency and complexity indicators'),
            const SizedBox(height: 10),
            EfficiencyMetrics(state: state),
            const SizedBox(height: 32),
          ],
        ),
      );
    });
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(subtitle,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}