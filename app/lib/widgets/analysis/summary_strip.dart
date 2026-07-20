import 'package:flutter/material.dart';
import '../../services/analysis_state.dart';
import '../../theme/app_colors.dart';

/// Section 1 — Top banner with at-a-glance procedure stats.
class SummaryStrip extends StatelessWidget {
  final AnalysisState state;
  const SummaryStrip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final dur     = state.totalDuration;
    final mm      = (dur ~/ 60).toString().padLeft(2, '0');
    final ss      = (dur.toInt() % 60).toString().padLeft(2, '0');
    final durStr  = '$mm:$ss';

    final tiles = [
      _Tile('DURATION',       durStr,                    'min:sec',  AppColors.accentCyan),
      _Tile('PHASES',         '${state.phaseTimeline.length}',   'detected', AppColors.accentCyan),
      _Tile('TRANSITIONS',    '${state.transitionCount}',         'changes',  AppColors.accentAmber),
      _Tile('INSTRUMENTS',    '${state.toolDiversityScore}',      'active',   AppColors.accentCyan),
      _Tile('DOMINANT PHASE', _short(state.dominantPhase),        'longest',  AppColors.accentGreen),
      _Tile('TOP INSTRUMENT', state.dominantTool,                 'most used',AppColors.accentGreen),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 700 ? 6 : (constraints.maxWidth > 450 ? 3 : 2);
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: tiles.map((t) => _buildTile(t)).toList(),
      );
    });
  }

  Widget _buildTile(_Tile t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t.label,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  letterSpacing: 0.8)),
          Text(t.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: t.color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          Text(t.unit,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 9)),
        ],
      ),
    );
  }

  // Abbreviate long phase names so they fit the tile
  String _short(String phase) {
    const map = {
      'CalotTriangleDissection': 'Calot Dissect.',
      'CleaningCoagulation':     'Cleaning/Coag.',
      'ClippingCutting':         'Clipping/Cut.',
      'GallbladderDissection':   'GB Dissection',
      'GallbladderPackaging':    'GB Packaging',
      'GallbladderRetraction':   'GB Retraction',
      'Preparation':             'Preparation',
    };
    return map[phase] ?? phase;
  }
}

class _Tile {
  final String label, value, unit;
  final Color  color;
  const _Tile(this.label, this.value, this.unit, this.color);
}