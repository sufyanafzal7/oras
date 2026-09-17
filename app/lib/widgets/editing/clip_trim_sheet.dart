import 'package:flutter/material.dart';
import '../../models/timeline_clip.dart';
import '../../theme/app_colors.dart';
import 'video_preview_player.dart';

/// Bottom sheet for precisely setting a clip's in/out points against
/// its full source video. Returns the updated [TimelineClip] via
/// Navigator.pop, or null if cancelled.
class ClipTrimSheet extends StatefulWidget {
  final TimelineClip clip;
  final String sourceUrl;

  const ClipTrimSheet({
    super.key,
    required this.clip,
    required this.sourceUrl,
  });

  static Future<TimelineClip?> show(
      BuildContext context, TimelineClip clip, String sourceUrl) {
    return showModalBottomSheet<TimelineClip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ClipTrimSheet(clip: clip, sourceUrl: sourceUrl),
    );
  }

  @override
  State<ClipTrimSheet> createState() => _ClipTrimSheetState();
}

class _ClipTrimSheetState extends State<ClipTrimSheet> {
  final _previewKey = GlobalKey<VideoPreviewPlayerState>();
  double _sourceDuration = 0.0;
  late double _start;
  late double _end;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start = widget.clip.startSeconds;
    _end = widget.clip.endSeconds;
  }

  void _onReady() {
    final dur = _previewKey.currentState?.sourceDurationSeconds ?? 0.0;
    setState(() {
      _sourceDuration = dur > 0 ? dur : _end;
      _end = _end.clamp(_start, _sourceDuration);
      _ready = true;
    });
    _previewKey.currentState?.seekTo(_start);
  }

  void _previewAt(double seconds) {
    _previewKey.currentState?.seekTo(seconds);
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trim Clip',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: SizedBox.expand(
                  child: VideoPreviewPlayer(
                    key: _previewKey,
                    videoUrl: widget.sourceUrl,
                    onReady: _onReady,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_ready)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              RangeSlider(
                values: RangeValues(_start, _end),
                min: 0,
                max: _sourceDuration,
                activeColor: AppColors.accentCyan,
                inactiveColor: AppColors.border,
                onChanged: (v) {
                  setState(() {
                    _start = v.start;
                    _end = v.end;
                  });
                },
                onChangeEnd: (v) => _previewAt(v.start),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _previewAt(_start),
                    child: Text('Start  ${_fmt(_start)}',
                        style: const TextStyle(
                            color: AppColors.accentCyan, fontSize: 12)),
                  ),
                  Text('Length ${_fmt(_end - _start)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  GestureDetector(
                    onTap: () => _previewAt(_end),
                    child: Text('End  ${_fmt(_end)}',
                        style: const TextStyle(
                            color: AppColors.accentCyan, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _end > _start
                          ? () => Navigator.pop(
                          context,
                          widget.clip.copyWith(
                              startSeconds: _start, endSeconds: _end))
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.background,
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}