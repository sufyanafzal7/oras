// AFTER:
import 'package:flutter/material.dart';
import '../../models/stored_procedure.dart';
import '../../services/report_generator.dart';
import '../../services/pdf_saver.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// One collapsible card per [StoredProcedure] in the Reports tab.
///
/// Collapsed state:  file name | date | Download PDF | ▼ expand
/// Expanded state:   + 4 individual download buttons revealed below
class ReportCard extends StatefulWidget {
  final StoredProcedure procedure;
  final bool            isHighlighted;   // true when navigated from Download btn

  const ReportCard({
    super.key,
    required this.procedure,
    this.isHighlighted = false,
  });

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  // tracks which button is currently generating
  String? _loadingBtn;

  // highlight pulse
  late AnimationController _hlCtrl;
  late Animation<Color?>    _hlAnim;

  @override
  void initState() {
    super.initState();
    _hlCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _hlAnim = ColorTween(
      begin: AppColors.accentCyan.withValues(alpha: 0.0),
      end:   AppColors.accentCyan.withValues(alpha: 0.18),
    ).animate(CurvedAnimation(parent: _hlCtrl, curve: Curves.easeInOut));

    if (widget.isHighlighted) {
      _expanded = true;
      // pulse twice then stop
      _hlCtrl.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) _hlCtrl.stop();
      });
    }
  }

  @override
  void didUpdateWidget(ReportCard old) {
    super.didUpdateWidget(old);
    if (widget.isHighlighted && !old.isHighlighted) {
      setState(() => _expanded = true);
      _hlCtrl
        ..reset()
        ..repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 2400), () {
        if (mounted) _hlCtrl.stop();
      });
    }
  }

  @override
  void dispose() {
    _hlCtrl.dispose();
    super.dispose();
  }

  // ── PDF generation + share/save ──────────────────────────────────────────

  // AFTER:
  Future<void> _download(String btnKey, Future<List<int>> Function() build) async {
    if (_loadingBtn != null) return;
    setState(() => _loadingBtn = btnKey);
    try {
      final bytes = await build();
      final name  = widget.procedure.fileName.replaceAll(RegExp(r'\.\w+$'), '');
      final result = await savePdfBytes(
        bytes: bytes,
        filename: 'ORAS_${name}_$btnKey.pdf',
      );
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result == 'Shared' || result == 'Downloaded'
                ? 'Report ready'
                : 'Saved to $result',
          ),
          backgroundColor: AppColors.accentGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF generation failed: $e'),
          backgroundColor: AppColors.accentMagenta,
        ));
      }
    } finally {
      if (mounted) setState(() => _loadingBtn = null);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p         = widget.procedure;
    final phaseColor = kPhaseColors[p.dominantPhase] ?? AppColors.accentCyan;

    return AnimatedBuilder(
      animation: _hlAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: _hlAnim.value ?? AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isHighlighted
                ? AppColors.accentCyan.withValues(alpha: 0.6)
                : AppColors.border,
            width: widget.isHighlighted ? 1.5 : 1.0,
          ),
        ),
        child: child,
      ),
      child: Column(
        children: [
          // ── Header row (always visible) ──────────────────────────────────
          _buildHeader(p, phaseColor),

          // ── Expanded sub-buttons ─────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded ? _buildExpandedSection(p) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(StoredProcedure p, Color phaseColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          // colour dot for dominant phase
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: phaseColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // file name + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.formattedDate}  ·  ${p.formattedDuration}  '
                      '·  ${p.phaseCount} phases  ·  ${p.toolCount} instruments',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Download PDF button
          _ActionBtn(
            label: 'Download PDF',
            icon: Icons.download_rounded,
            color: AppColors.accentCyan,
            loading: _loadingBtn == 'full',
            onTap: () => _download('full',
                    () => ReportGenerator.generate(p).then((b) => b.toList())),
          ),
          const SizedBox(width: 6),

          // Expand / collapse toggle
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedRotation(
                turns: _expanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSection(StoredProcedure p) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Individual Downloads',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (ctx, constraints) {
            final isWide = constraints.maxWidth > 500;
            final buttons = [
              _SubBtn(
                label: 'Tools Timeline',
                sub:   'Instrument activity scrubber from Upload tab',
                icon:  Icons.hardware_outlined,
                color: AppColors.accentCyan,
                btnKey: 'tools_timeline',
                loading: _loadingBtn == 'tools_timeline',
                onTap: () => _download('tools_timeline',
                        () => ReportGenerator.generateToolsTimeline(p)
                        .then((b) => b.toList())),
              ),
              _SubBtn(
                label: 'Phase Timeline',
                sub:   'Phase Gantt scrubber from Upload tab',
                icon:  Icons.timeline_rounded,
                color: AppColors.accentGreen,
                btnKey: 'phase_timeline',
                loading: _loadingBtn == 'phase_timeline',
                onTap: () => _download('phase_timeline',
                        () => ReportGenerator.generatePhaseTimeline(p)
                        .then((b) => b.toList())),
              ),
              _SubBtn(
                label: 'Analysis Data',
                sub:   'All diagrams & metrics from Analysis tab',
                icon:  Icons.insights_rounded,
                color: AppColors.accentMagenta,
                btnKey: 'analysis',
                loading: _loadingBtn == 'analysis',
                onTap: () => _download('analysis',
                        () => ReportGenerator.generateAnalysisOnly(p)
                        .then((b) => b.toList())),
              ),
              _SubBtn(
                label: 'Upload Tab Data',
                sub:   'Info, timelines & distribution from Upload tab',
                icon:  Icons.cloud_upload_rounded,
                color: AppColors.accentAmber,
                btnKey: 'upload_data',
                loading: _loadingBtn == 'upload_data',
                onTap: () => _download('upload_data',
                        () => ReportGenerator.generateUploadData(p)
                        .then((b) => b.toList())),
              ),
            ];

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: buttons
                    .expand((b) => [Expanded(child: b), const SizedBox(width: 8)])
                    .toList()
                  ..removeLast(),
              );
            }
            return Column(
              children: buttons
                  .expand((b) => [b, const SizedBox(height: 8)])
                  .toList()
                ..removeLast(),
            );
          }),
        ],
      ),
    );
  }
}

// ── Small action button in header ─────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     loading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            )
                : Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expanded sub-download button ──────────────────────────────────────────────

class _SubBtn extends StatelessWidget {
  final String   label;
  final String   sub;
  final IconData icon;
  final Color    color;
  final String   btnKey;
  final bool     loading;
  final VoidCallback onTap;

  const _SubBtn({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    required this.btnKey,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            loading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
              ),
            )
                : Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              size: 14,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}