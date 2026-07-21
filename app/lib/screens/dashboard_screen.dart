import 'package:flutter/material.dart';
import '../models/stored_procedure.dart';
import '../services/procedure_store.dart';
import '../services/analysis_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_constants.dart';
import '../widgets/dashboard/metric_card.dart';
import '../widgets/dashboard/procedure_card.dart';

class DashboardScreen extends StatefulWidget {
  final void Function(int)? onSwitchTab;
  const DashboardScreen({super.key, this.onSwitchTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    ProcedureStore.instance.addListener(_onStoreChange);
  }

  @override
  void dispose() {
    ProcedureStore.instance.removeListener(_onStoreChange);
    super.dispose();
  }

  void _onStoreChange() {
    if (mounted) setState(() {});
  }

  // ── Tap a procedure card ─────────────────────────────────────────────────
  void _openProcedure(StoredProcedure p) {
    // Load analysis data back into the shared singleton
    AnalysisState.instance.setResult(p.rawResult);
    // Switch to Upload tab (index 1) so the scrubbers and video panel show
    widget.onSwitchTab?.call(1);
  }

  @override
  Widget build(BuildContext context) {
    final store = ProcedureStore.instance;
    final procs = store.procedures;
    final empty = procs.isEmpty;

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const Text('INTELLIGENCE OVERVIEW',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    letterSpacing: 1)),
            const SizedBox(height: 4),
            const Text('Tactical Command',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // ── Top stats + action button ────────────────────────────────────
            _buildTopRow(store),
            const SizedBox(height: 16),

            // ── 4 metric cards ───────────────────────────────────────────────
            _buildMetricsGrid(store),
            const SizedBox(height: 24),

            // ── Phase distribution bar (aggregated) ──────────────────────────
            if (!empty) ...[
              _buildAggregatedPhaseChart(procs),
              const SizedBox(height: 24),
            ],

            // ── Tool frequency bar ───────────────────────────────────────────
            if (!empty) ...[
              _buildToolFrequencyChart(procs),
              const SizedBox(height: 24),
            ],

            // ── Recent procedures list ───────────────────────────────────────
            _buildProceduresHeader(store),
            const SizedBox(height: 12),
            empty ? _buildEmptyState() : _buildProcedureGallery(procs),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Top row: stats + Analyze New button ──────────────────────────────────
  Widget _buildTopRow(ProcedureStore store) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;

      final statsBlock = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: _statTile(
                'Total Procedures Analyzed',
                '${store.totalCount}',
                'videos',
              ),
            ),
            Container(width: 1, height: 40, color: AppColors.border),
            Expanded(
              child: _statTile(
                'Total Runtime Processed',
                store.formattedTotalRuntime,
                'hh:mm:ss',
              ),
            ),
          ],
        ),
      );

      final analyzeButton = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: () => widget.onSwitchTab?.call(1),
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.cloud_upload_rounded,
                    color: AppColors.accentCyan),
              ),
              const SizedBox(height: 8),
              const Text('Analyze New',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 2),
              const Text('Upload a surgical video',
                  textAlign: TextAlign.center,
                  style:
                  TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ),
      );

      if (isWide) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: statsBlock),
              const SizedBox(width: 12),
              Expanded(child: analyzeButton),
            ],
          ),
        );
      }
      return Column(children: [
        statsBlock,
        const SizedBox(height: 12),
        analyzeButton,
      ]);
    });
  }

  Widget _statTile(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 4),
              Text(unit,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4 metric cards ────────────────────────────────────────────────────────
  Widget _buildMetricsGrid(ProcedureStore store) {
    final empty = store.totalCount == 0;

    // Sparkline: last 7 procedure durations normalised 0-1
    List<double> _durationSparkline() {
      final procs = store.procedures.take(7).toList().reversed.toList();
      if (procs.isEmpty) return List.filled(7, 0.0);
      final max = procs.map((p) => p.durationSeconds).reduce((a, b) => a > b ? a : b);
      if (max == 0) return List.filled(procs.length, 0.0);
      final vals = procs.map((p) => p.durationSeconds / max).toList();
      while (vals.length < 7) vals.insert(0, 0.0);
      return vals;
    }

    // Sparkline: phases per procedure
    List<double> _phaseSparkline() {
      final procs = store.procedures.take(7).toList().reversed.toList();
      if (procs.isEmpty) return List.filled(7, 0.0);
      final max = procs.map((p) => p.phaseCount.toDouble()).reduce((a, b) => a > b ? a : b);
      if (max == 0) return List.filled(procs.length, 0.0);
      final vals = procs.map((p) => p.phaseCount / max).toList();
      while (vals.length < 7) vals.insert(0, 0.0);
      return vals;
    }

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          MetricCard(
            label: 'AVG DURATION',
            value: empty ? '—' : store.formattedAverageDuration,
            accentColor: AppColors.accentCyan,
            sparkline: _durationSparkline(),
            trailingIcon: Icons.timer_outlined,
          ),
          MetricCard(
            label: 'AVG PHASES',
            value: empty
                ? '—'
                : store.procedures
                .map((p) => p.phaseCount)
                .reduce((a, b) => a + b)
                .toString()
                .let((_) => (store.procedures
                .map((p) => p.phaseCount)
                .reduce((a, b) => a + b) /
                store.totalCount)
                .toStringAsFixed(1)),
            accentColor: AppColors.accentCyan,
            sparkline: _phaseSparkline(),
            trailingIcon: Icons.layers_rounded,
          ),
          MetricCard(
            label: 'TOP PHASE',
            value: empty ? '—' : _shortPhase(store.globalDominantPhase),
            accentColor: AppColors.accentGreen,
            sparkline: const [0.4, 0.6, 0.5, 0.8, 0.7, 0.9, 0.85],
            trailingIcon: Icons.trending_up_rounded,
          ),
          MetricCard(
            label: 'TOP INSTRUMENT',
            value: empty ? '—' : store.globalDominantTool,
            accentColor: AppColors.accentAmber,
            sparkline: const [0.3, 0.5, 0.4, 0.6, 0.5, 0.7, 0.65],
            trailingIcon: Icons.hardware_outlined,
          ),
        ],
      );
    });
  }

  // ── Aggregated phase distribution across ALL procedures ───────────────────
  Widget _buildAggregatedPhaseChart(List<StoredProcedure> procs) {
    // Sum duration per phase across all procedures
    final totals = <String, double>{};
    for (final p in procs) {
      final timeline = p.rawResult['phase_timeline'] as List? ?? [];
      for (final seg in timeline) {
        final m     = seg as Map<String, dynamic>;
        final phase = m['phase'] as String;
        final dur   = ((m['end_time'] as num).toDouble() -
            (m['start_time'] as num).toDouble())
            .clamp(0.0, double.infinity);
        totals[phase] = (totals[phase] ?? 0) + dur;
      }
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    final grand = totals.values.fold(0.0, (a, b) => a + b);
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ChartCard(
      title: 'PHASE DISTRIBUTION',
      subtitle: 'Cumulative phase time across all ${procs.length} procedure(s)',
      child: Column(
        children: sorted.map((e) {
          final color = kPhaseColors[e.key] ?? AppColors.textMuted;
          final frac  = grand > 0 ? e.value / grand : 0.0;
          final mm    = (e.value ~/ 60).toString().padLeft(2, '0');
          final ss    = (e.value.toInt() % 60).toString().padLeft(2, '0');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e.key,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ),
                  Text('$mm:$ss  ${(frac * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: color, fontSize: 11)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: frac,
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        color.withValues(alpha: 0.85)),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Aggregated tool frequency across ALL procedures ───────────────────────
  Widget _buildToolFrequencyChart(List<StoredProcedure> procs) {
    final totals = <String, int>{};
    for (final p in procs) {
      final tools = p.rawResult['tools_detected'] as List? ?? [];
      for (final t in tools) {
        final m    = t as Map<String, dynamic>;
        final tool = m['tool'] as String;
        final fr   = (m['frames_detected'] as num).toInt();
        totals[tool] = (totals[tool] ?? 0) + fr;
      }
    }
    if (totals.isEmpty) return const SizedBox.shrink();
    final max    = totals.values.reduce((a, b) => a > b ? a : b).toDouble();
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const toolColors = {
      'grasper':     Color(0xFF4FC3F7),
      'bipolar':     Color(0xFFE8447A),
      'hook':        Color(0xFF81C784),
      'scissors':    Color(0xFFBA68C8),
      'clipper':     Color(0xFFFFB74D),
      'irrigator':   Color(0xFF4DB6AC),
      'specimenbag': Color(0xFFFFD54F),
    };

    return _ChartCard(
      title: 'INSTRUMENT FREQUENCY',
      subtitle: 'Total frames detected per instrument across all procedures',
      child: Column(
        children: sorted.map((e) {
          final color = toolColors[e.tool] ?? AppColors.textMuted;
          final frac  = max > 0 ? e.value / max : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(
                width: 80,
                child: Text(e.tool,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ),
              Expanded(
                child: LayoutBuilder(builder: (_, c) {
                  return Stack(children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 18,
                      width: c.maxWidth * frac,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ]);
                }),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: Text('${e.value}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Procedures header row ─────────────────────────────────────────────────
  Widget _buildProceduresHeader(ProcedureStore store) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Analyzed Procedures',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        if (store.totalCount > 0)
          TextButton(
            onPressed: () => _confirmClear(context),
            child: const Text('Clear All',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12)),
          ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.video_library_outlined,
                color: AppColors.accentCyan, size: 26),
          ),
          const SizedBox(height: 14),
          const Text('No procedures analyzed yet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            'Upload and analyze a surgical video in the Upload tab.\nIt will appear here automatically once complete.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => widget.onSwitchTab?.call(1),
            icon: const Icon(Icons.cloud_upload_rounded, size: 15),
            label: const Text('Go to Upload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ── Horizontal card gallery ───────────────────────────────────────────────
  Widget _buildProcedureGallery(List<StoredProcedure> procs) {
    return SizedBox(
      height: 205,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: procs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => ProcedureCard(
          procedure: procs[index],
          onTap: () => _openProcedure(procs[index]),
        ),
      ),
    );
  }

  // ── Clear all confirmation dialog ─────────────────────────────────────────
  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Clear all procedures?',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        content: const Text(
          'This removes all stored analysis records from this device. '
              'The original video files are not deleted.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              ProcedureStore.instance.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All',
                style: TextStyle(color: AppColors.accentMagenta)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _shortPhase(String p) {
    const map = {
      'CalotTriangleDissection': 'Calot',
      'CleaningCoagulation':     'Cleaning',
      'ClippingCutting':         'Clipping',
      'GallbladderDissection':   'GB Diss.',
      'GallbladderPackaging':    'GB Pack.',
      'GallbladderRetraction':   'GB Retr.',
      'Preparation':             'Prep',
    };
    return map[p] ?? p;
  }
}

// ── Reusable chart card container ─────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// Extension to avoid awkward let() logic
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// MapEntry extension for tool name access
extension _ToolEntry on MapEntry<String, int> {
  String get tool => key;
}