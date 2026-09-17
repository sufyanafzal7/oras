import 'package:flutter/material.dart';
import '../../models/edit_timeline.dart';
import '../../theme/app_colors.dart';

/// One saved editing timeline, shown as a card in the Video Editing tab.
/// Tapping reopens the editor; the trailing icon deletes it.
class TimelineCard extends StatelessWidget {
  final EditTimeline timeline;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TimelineCard({
    super.key,
    required this.timeline,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentMagenta.withValues(alpha: 0.18),
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
                      const Icon(Icons.content_cut_rounded,
                          color: AppColors.accentMagenta, size: 26),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          timeline.formattedDuration,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      timeline.isExported ? 'EXPORTED' : 'DRAFT',
                      style: TextStyle(
                        color: timeline.isExported
                            ? AppColors.accentGreen
                            : AppColors.accentAmber,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: AppColors.textMuted),
                    onPressed: onDelete,
                    splashRadius: 16,
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
                    timeline.name,
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
                      '${timeline.clips.length} clip${timeline.clips.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                    ),
                    if (timeline.overlays.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.text_fields_rounded,
                          size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${timeline.overlays.length}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
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