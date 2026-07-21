import 'package:flutter/material.dart';
import '../../models/stored_procedure.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_constants.dart';

class ProcedureCard extends StatelessWidget {
  final StoredProcedure procedure;
  final VoidCallback?   onTap;

  const ProcedureCard({
    super.key,
    required this.procedure,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final phaseColor = kPhaseColors[procedure.dominantPhase] ??
        AppColors.accentCyan;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail area ──────────────────────────────────────────────
            Stack(
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        phaseColor.withValues(alpha: 0.18),
                        AppColors.surfaceElevated,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded,
                          color: phaseColor.withValues(alpha: 0.7),
                          size: 28),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                          AppColors.background.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          procedure.formattedDuration,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // "ANALYZED" badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.statusCompleted,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'ANALYZED',
                          style: TextStyle(
                            color: AppColors.statusCompleted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Phase count chip — top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border:
                      Border.all(color: phaseColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${procedure.phaseCount} phases',
                      style: TextStyle(
                          color: phaseColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),

            // ── Info area ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    procedure.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.layers_rounded,
                        size: 10, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      procedure.dominantPhase,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: phaseColor, fontSize: 10),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.hardware_outlined,
                        size: 10, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${procedure.toolCount} instruments',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                    ),
                    const Spacer(),
                    Text(
                      procedure.formattedDate.split('  ').last,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 9),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}