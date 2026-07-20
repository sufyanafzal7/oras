import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 5 — Horizontal bar chart of tool usage, sorted descending.
class ToolBarChart extends StatefulWidget {
  final AnalysisState state;
  const ToolBarChart({super.key, required this.state});

  @override
  State<ToolBarChart> createState() => _ToolBarChartState();
}

class _ToolBarChartState extends State<ToolBarChart> {
  String? _hovered;

  static const _toolColors = {
    'grasper':     Color(0xFF4FC3F7),
    'bipolar':     Color(0xFFE8447A),
    'hook':        Color(0xFF81C784),
    'scissors':    Color(0xFFBA68C8),
    'clipper':     Color(0xFFFFB74D),
    'irrigator':   Color(0xFF4DB6AC),
    'specimenbag': Color(0xFFFFD54F),
  };

  @override
  Widget build(BuildContext context) {
    final sorted = widget.state.toolsSorted;
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxFrames = sorted.first.framesDetected.toDouble();

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
          const Text('Instrument Usage',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Frames detected per instrument',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 16),
          // Bars — all 7 tools, inactive ones shown greyed out
          ...kAllTools.map((toolName) {
            final result = sorted.cast<ToolResult?>().firstWhere(
                  (t) => t?.tool == toolName,
              orElse: () => null,
            );
            final frames   = result?.framesDetected ?? 0;
            final frac     = maxFrames > 0 ? frames / maxFrames : 0.0;
            final color    = _toolColors[toolName] ?? AppColors.textMuted;
            final active   = result != null;
            final isHl     = _hovered == toolName;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = toolName),
              onExit:  (_) => setState(() => _hovered = null),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(
                    width: 88,
                    child: Text(toolName,
                        style: TextStyle(
                            color: active
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: active
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (_, c) {
                      return Stack(children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (active)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 20,
                            width: c.maxWidth * frac,
                            decoration: BoxDecoration(
                              color: color.withValues(
                                  alpha: isHl ? 1.0 : 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        // Frame count label inside bar
                        if (active && frac > 0.15)
                          Positioned(
                            left: 6,
                            top: 0, bottom: 0,
                            child: Center(
                              child: Text('$frames',
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]);
                    }),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      active ? '$frames' : '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: active ? color : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}