import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 8 — Phase × Tool co-occurrence matrix.
/// Rows = phases, Columns = tools. Cell color intensity = presence.
class CooccurrenceMatrix extends StatefulWidget {
  final AnalysisState state;
  const CooccurrenceMatrix({super.key, required this.state});

  @override
  State<CooccurrenceMatrix> createState() => _CooccurrenceMatrixState();
}

class _CooccurrenceMatrixState extends State<CooccurrenceMatrix> {
  String? _hoveredPhase;
  String? _hoveredTool;

  static const _phases = [
    'Preparation',
    'CalotTriangleDissection',
    'ClippingCutting',
    'GallbladderDissection',
    'GallbladderPackaging',
    'CleaningCoagulation',
    'GallbladderRetraction',
  ];

  static const _phaseShort = {
    'Preparation':             'Prep',
    'CalotTriangleDissection': 'Calot',
    'ClippingCutting':         'Clip/Cut',
    'GallbladderDissection':   'GB Diss.',
    'GallbladderPackaging':    'GB Pack.',
    'CleaningCoagulation':     'Cleaning',
    'GallbladderRetraction':   'GB Retr.',
  };

  static const _toolShort = {
    'grasper':     'Grasp',
    'bipolar':     'Bipol',
    'hook':        'Hook',
    'scissors':    'Scissor',
    'clipper':     'Clip',
    'irrigator':   'Irrig',
    'specimenbag': 'Bag',
  };

  @override
  Widget build(BuildContext context) {
    final toolMap = widget.state.phaseToolMap;
    final pcts    = widget.state.phasePercentages;

    // Filter to only phases that appeared
    final activePhases = _phases
        .where((p) => pcts.containsKey(p))
        .toList();
    if (activePhases.isEmpty) return const SizedBox.shrink();

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
          const Text(
            'Each cell shows whether an instrument was active during that phase.\n'
                'Darker = more likely present based on detection frequency.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.5),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column headers (tools)
                Row(children: [
                  const SizedBox(width: 90), // phase label offset
                  ...kAllTools.map((tool) {
                    final isHl = _hoveredTool == tool;
                    return MouseRegion(
                      onEnter: (_) =>
                          setState(() => _hoveredTool = tool),
                      onExit: (_) =>
                          setState(() => _hoveredTool = null),
                      child: SizedBox(
                        width: 56,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              _toolShort[tool] ?? tool,
                              style: TextStyle(
                                color: isHl
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: isHl
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ]),
                const SizedBox(height: 4),
                // Rows (phases)
                ...activePhases.map((phase) {
                  final tools  = toolMap[phase] ?? {};
                  final phaseColor = kPhaseColors[phase] ??
                      const Color(0xFF5A6A7A);
                  final isHlRow = _hoveredPhase == phase;

                  return MouseRegion(
                    onEnter: (_) =>
                        setState(() => _hoveredPhase = phase),
                    onExit: (_) =>
                        setState(() => _hoveredPhase = null),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        // Phase label
                        SizedBox(
                          width: 90,
                          child: Text(
                            _phaseShort[phase] ?? phase,
                            style: TextStyle(
                              color: isHlRow
                                  ? phaseColor
                                  : AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: isHlRow
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        // Cells
                        ...kAllTools.map((tool) {
                          final present  = tools.contains(tool);
                          final isHlCol  = _hoveredTool == tool;
                          final isHlCell = isHlRow || isHlCol;

                          return Tooltip(
                            message: present
                                ? '$tool detected during $phase'
                                : '$tool not detected during $phase',
                            textStyle: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                              border:
                              Border.all(color: AppColors.border),
                            ),
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 150),
                              width: 52,
                              height: 32,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: present
                                    ? phaseColor.withValues(
                                    alpha: isHlCell ? 0.9 : 0.55)
                                    : (isHlCell
                                    ? AppColors.border
                                    : AppColors.background),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: present
                                      ? phaseColor.withValues(
                                      alpha: 0.4)
                                      : AppColors.border,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                present
                                    ? Icons.check_rounded
                                    : Icons.remove,
                                size: 14,
                                color: present
                                    ? Colors.white
                                    .withValues(alpha: 0.9)
                                    : AppColors.textMuted
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                          );
                        }),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(children: [
            Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 6),
            const Text('Instrument present',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(width: 16),
            Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border))),
            const SizedBox(width: 6),
            const Text('Not detected',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
          ]),
        ],
      ),
    );
  }
}