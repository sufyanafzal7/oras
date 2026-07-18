import 'package:flutter/material.dart';
import '../../models/procedure.dart';
import '../../theme/app_colors.dart';

class ProcedureCard extends StatelessWidget {
  final Procedure procedure;
  final VoidCallback? onTap;

  const ProcedureCard({super.key, required this.procedure, this.onTap});

  Color get _statusColor {
    switch (procedure.status) {
      case ProcedureStatus.completed:
        return AppColors.statusCompleted;
      case ProcedureStatus.analyzing:
        return AppColors.statusAnalyzing;
      case ProcedureStatus.failed:
        return AppColors.statusAlert;
    }
  }

  String get _statusLabel {
    switch (procedure.status) {
      case ProcedureStatus.completed:
        return 'COMPLETED';
      case ProcedureStatus.analyzing:
        return 'ANALYZING';
      case ProcedureStatus.failed:
        return 'FAILED';
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Placeholder visual — Phase 5 swaps this for a real
            // frame grab once the ingestion pipeline exists.
            Stack(
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _statusColor.withValues(alpha: 0.25),
                        AppColors.surfaceElevated,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.videocam_rounded,
                      color: _statusColor.withValues(alpha: 0.6), size: 32),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: _statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    procedure.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    procedure.surgeonName,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}