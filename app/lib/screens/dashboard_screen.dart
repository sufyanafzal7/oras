import 'package:flutter/material.dart';
import '../models/procedure.dart';
import '../services/mock_data_service.dart';
import '../theme/app_colors.dart';
import '../widgets/dashboard/metric_card.dart';
import '../widgets/dashboard/procedure_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  List<Procedure> _procedures = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await MockDataService.fetchDashboardSummary();
    final procedures = await MockDataService.fetchRecentProcedures();
    setState(() {
      _summary = summary;
      _procedures = procedures;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentCyan),
      );
    }

    final summary = _summary!;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accentCyan,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _buildTopRow(summary),
            const SizedBox(height: 16),
            _buildMetricsGrid(summary),
            const SizedBox(height: 24),
            _buildRecentProceduresHeader(),
            const SizedBox(height: 12),
            _buildRecentProceduresGallery(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(Map<String, dynamic> summary) {
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
              child: _statTile('Total Procedures Analyzed',
                  '${summary['totalProcedures']}', 'units'),
            ),
            Container(width: 1, height: 40, color: AppColors.border),
            Expanded(
              child: _statTile('Total Hours Processed',
                  '${summary['totalHoursProcessed']}h', 'runtime'),
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
          onTap: () {}, // Phase 5: route to real ingestion flow
          child: Column(
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
              const Text('Initiate surgical telemetry ingest',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
      return Column(
          children: [statsBlock, const SizedBox(height: 12), analyzeButton]);
    });
  }

  Widget _statTile(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Text(unit,
                style:
                const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> summary) {
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
            label: 'PHASE PRECISION',
            value: '+${summary['phasePrecision']}%',
            accentColor: AppColors.accentCyan,
            sparkline: const [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.9],
            trailingIcon: Icons.trending_up_rounded,
          ),
          MetricCard(
            label: 'EFFICIENCY DELTA',
            value: '${summary['efficiencyDelta']}m',
            accentColor: AppColors.accentCyan,
            sparkline: const [0.6, 0.5, 0.7, 0.5, 0.6, 0.8, 0.7],
            trailingIcon: Icons.trending_up_rounded,
          ),
          MetricCard(
            label: 'BLOOD LOSS INDEX',
            value: '${summary['bloodLossIndex']}',
            accentColor: AppColors.accentAmber,
            sparkline: const [0.2, 0.3, 0.2, 0.4, 0.3, 0.2, 0.3],
            trailingIcon: Icons.warning_amber_rounded,
          ),
          MetricCard(
            label: 'INSTRUMENT UPTIME',
            value: '${summary['instrumentUptime']}%',
            accentColor: AppColors.accentCyan,
            sparkline: const [0.8, 0.9, 0.85, 0.9, 0.95, 0.9, 0.95],
          ),
        ],
      );
    });
  }

  Widget _buildRecentProceduresHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Text('Recent Procedures',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        Text('View Intelligence Vault',
            style: TextStyle(color: AppColors.accentCyan, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecentProceduresGallery() {
    return SizedBox(
      height: 175,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _procedures.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            ProcedureCard(procedure: _procedures[index]),
      ),
    );
  }
}