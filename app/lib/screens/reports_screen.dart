import 'package:flutter/material.dart';
import '../services/procedure_store.dart';
import '../theme/app_colors.dart';
import '../widgets/reports/report_card.dart';

/// Tab 4 — Reports
///
/// Listens to [ProcedureStore] and renders one [ReportCard] per
/// stored procedure (newest first).
///
/// [highlightedProcedureId] — when non-null, that card pulses and
/// auto-expands. Set by the Upload tab's "Download" button.
class ReportsScreen extends StatefulWidget {
  final String? highlightedProcedureId;

  const ReportsScreen({super.key, this.highlightedProcedureId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final procs = ProcedureStore.instance.procedures;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(procs.length),
          Expanded(
            child: procs.isEmpty
                ? _buildEmptyState()
                : _buildList(procs),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(int count) {
    return Container(
      height: 52,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.description_rounded,
              color: AppColors.accentCyan, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Reports',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count > 0 ? '$count report${count == 1 ? '' : 's'}' : 'No reports yet',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const Spacer(),
          if (count > 0)
            Text(
              'Tap ▼ on any card to see individual downloads',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
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
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.accentCyan,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No reports yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload and analyze a video in the Upload tab.\n'
                'A report card will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── List of report cards ──────────────────────────────────────────────────
  Widget _buildList(List procs) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: procs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final proc = procs[index];
        return ReportCard(
          key: ValueKey(proc.id),
          procedure: proc,
          isHighlighted: proc.id == widget.highlightedProcedureId,
        );
      },
    );
  }
}