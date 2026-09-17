import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/timeline_overlay.dart';
import '../../theme/app_colors.dart';

/// Renders whichever overlays are active at [currentTime] on top of the
/// video preview. Tap an overlay to select/edit it; drag to reposition.
/// This is an APPROXIMATION for live editing only — the real, pixel-
/// accurate composite happens server-side at export (see video_editor.py).
class OverlayLayer extends StatelessWidget {
  final List<TimelineOverlay> overlays;
  final double currentTime;
  final String? selectedId;
  final ValueChanged<TimelineOverlay> onTap;
  final void Function(TimelineOverlay overlay, double dxFrac, double dyFrac) onDrag;

  const OverlayLayer({
    super.key,
    required this.overlays,
    required this.currentTime,
    required this.onTap,
    required this.onDrag,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final active = overlays.where((o) =>
      currentTime >= o.startSeconds &&
          currentTime <= o.startSeconds + o.durationSeconds);

      return Stack(
        children: active.map((o) {
          final left = o.x * constraints.maxWidth;
          final top = o.y * constraints.maxHeight;
          final selected = o.id == selectedId;

          return Positioned(
            left: left,
            top: top,
            child: GestureDetector(
              onTap: () => onTap(o),
              onPanUpdate: (d) => onDrag(
                o,
                d.delta.dx / constraints.maxWidth,
                d.delta.dy / constraints.maxHeight,
              ),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  border: selected
                      ? Border.all(color: AppColors.accentCyan, width: 1.5)
                      : null,
                ),
                child: o.type == OverlayType.text
                    ? Text(
                  o.content,
                  style: TextStyle(
                    color: o.colorHex != null
                        ? Color(int.parse(
                        o.colorHex!.replaceFirst('#', '0xFF')))
                        : Colors.white,
                    fontSize: o.fontSize ?? 24,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                )
                    : SizedBox(
                  width: (o.widthFrac ?? 0.3) * constraints.maxWidth,
                  child: kIsWeb
                      ? const Icon(Icons.image_rounded,
                      color: Colors.white, size: 40)
                      : Image.file(File(o.content), fit: BoxFit.contain),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }
}