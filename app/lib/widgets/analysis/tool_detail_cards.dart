import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

/// Section 7 — One card per detected instrument with usage stats.
class ToolDetailCards extends StatelessWidget {
  final AnalysisState state;
  const ToolDetailCards({super.key, required this.state});

  static const _toolColors = {
    'grasper':     Color(0xFF4FC3F7),
    'bipolar':     Color(0xFFE8447A),
    'hook':        Color(0xFF81C784),
    'scissors':    Color(0xFFBA68C8),
    'clipper':     Color(0xFFFFB74D),
    'irrigator':   Color(0xFF4DB6AC),
    'specimenbag': Color(0xFFFFD54F),
  };

  static const _toolDescriptions = {
    'grasper':     'Grasps and retracts tissue',
    'bipolar':     'Bipolar electrocautery',
    'hook':        'Monopolar hook dissector',
    'scissors':    'Dissection scissors',
    'clipper':     'Clip applier for vessels/ducts',
    'irrigator':   'Irrigation and suction',
    'specimenbag': 'Specimen retrieval bag',
  };

  String _fmt(double s) {
    final m   = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final tools      = state.toolsSorted;
    final total      = state.totalDuration;
    final fps        = state.fps;
    final totalSamp  = (total * fps / 2).clamp(1.0, double.infinity);
    final toolMap    = state.phaseToolMap;
    final maxFrames  = tools.isNotEmpty
        ? tools.first.framesDetected.toDouble()
        : 1.0;

    // Which phases each tool appeared in
    final toolPhaseMap = <String, List<String>>{};
    toolMap.forEach((phase, toolSet) {
      for (final t in toolSet) {
        toolPhaseMap.putIfAbsent(t, () => []).add(phase);
      }
    });

    // Show all 7 tools, greyed if not detected
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 4 :
      constraints.maxWidth > 450 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: kAllTools.map((toolName) {
          final result  = tools.cast<ToolResult?>().firstWhere(
                (t) => t?.tool == toolName,
            orElse: () => null,
          );
          final active  = result != null;
          final frames  = result?.framesDetected ?? 0;
          final frac    = active ? (frames / maxFrames).clamp(0.0, 1.0) : 0.0;
          final activeSec = (frames / totalSamp) * total;
          final color   = _toolColors[toolName] ?? AppColors.textMuted;
          final phases  = toolPhaseMap[toolName] ?? [];

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? color.withValues(alpha: 0.3)
                    : AppColors.border,
                width: active ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tool name + status badge
                Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: active ? color : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(toolName,
                        style: TextStyle(
                            color: active
                                ? color
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (!active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('absent',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 8)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(_toolDescriptions[toolName] ?? '',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 9)),
                const SizedBox(height: 10),
                // Usage bar
                Stack(children: [
                  Container(
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(2))),
                  FractionallySizedBox(
                    widthFactor: frac,
                    child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                            color: active ? color : AppColors.textMuted,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                ]),
                const SizedBox(height: 8),
                if (active) ...[
                  _stat('Frames', '$frames'),
                  const SizedBox(height: 4),
                  _stat('Est. active', _fmt(activeSec)),
                  const Spacer(),
                  if (phases.isNotEmpty) ...[
                    const Text('Active during',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            letterSpacing: 0.4)),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      children: phases.take(3).map((p) {
                        final pc = kPhaseColors[p] ??
                            const Color(0xFF5A6A7A);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: pc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(_shortPhase(p),
                              style: TextStyle(
                                  color: pc, fontSize: 8)),
                        );
                      }).toList(),
                    ),
                  ],
                ] else
                  const Expanded(
                    child: Center(
                      child: Text('Not detected\nin this procedure',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              height: 1.5)),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _stat(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 9)),
      Text(value,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    ],
  );

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