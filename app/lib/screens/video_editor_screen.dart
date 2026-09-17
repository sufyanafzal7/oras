import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/edit_timeline.dart';
import '../models/timeline_clip.dart';
import '../models/timeline_overlay.dart';
import '../services/api_service.dart';
import '../services/edit_timeline_store.dart';
import '../services/editor_api_service.dart';
import '../services/video_saver.dart';
import '../theme/app_colors.dart';
import '../widgets/editing/clip_trim_sheet.dart';
import '../widgets/editing/overlay_edit_sheet.dart';
import '../widgets/editing/overlay_layer.dart';
import '../widgets/editing/video_preview_player.dart';

/// The CapCut-style editor: preview playback stitched across trimmed
/// clips, reorder/delete/import clips, text & image overlays, and
/// backend-rendered export.
class VideoEditorScreen extends StatefulWidget {
  final EditTimeline timeline;

  const VideoEditorScreen({super.key, required this.timeline});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  late EditTimeline _timeline;
  final _previewKey = GlobalKey<VideoPreviewPlayerState>();

  int? _selectedClipIndex;
  String? _selectedOverlayId;
  int _playingClipIndex = 0;
  bool _isPlaying = false;
  bool _transitioning = false; // guards against re-entrant clip jumps
  bool _exporting = false;
  double _timelinePosition = 0.0; // seconds, position within the STITCHED result

  @override
  void initState() {
    super.initState();
    _timeline = widget.timeline;
  }

  // ── Source resolution ────────────────────────────────────────────────────

  /// The URL/path to play for a given clip — its own imported file if it
  /// has one, otherwise the timeline's primary source video.
  String? _sourceFor(TimelineClip clip) {
    if (clip.importedFilePath != null) return clip.importedFilePath;
    if (_timeline.sourceJobId != null) {
      return ApiService.videoUrl(_timeline.sourceJobId!);
    }
    if (!kIsWeb && _timeline.sourceFilePath != null) {
      return _timeline.sourceFilePath;
    }
    return null;
  }

  /// Cumulative timeline-time offset where each clip begins.
  List<double> get _clipOffsets {
    final offsets = <double>[];
    var acc = 0.0;
    for (final c in _timeline.clips) {
      offsets.add(acc);
      acc += c.durationSeconds;
    }
    return offsets;
  }

  double get _totalDuration => _timeline.totalDurationSeconds;

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> _playFromClip(int index, {double? sourceSeekSeconds}) async {
    if (index < 0 || index >= _timeline.clips.length) {
      _stop();
      return;
    }
    final clip = _timeline.clips[index];
    final url = _sourceFor(clip);
    if (url == null) return;

    setState(() {
      _playingClipIndex = index;
      _selectedClipIndex = index;
    });

    await _previewKey.currentState?.load(url);
    _previewKey.currentState?.seekTo(sourceSeekSeconds ?? clip.startSeconds);
    if (_isPlaying) _previewKey.currentState?.play();
  }

  void _togglePlay() {
    if (_timeline.clips.isEmpty) return;
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _previewKey.currentState?.play();
    } else {
      _previewKey.currentState?.pause();
    }
  }

  void _stop() {
    setState(() {
      _isPlaying = false;
      _timelinePosition = _totalDuration;
    });
    _previewKey.currentState?.pause();
  }

  /// Called on every native player time tick. Detects when the current
  /// clip's trimmed OUT point is reached and jumps to the next clip —
  /// this is what makes several trimmed ranges from one source play
  /// back as one continuous stitched preview.
  void _onSourceTimeUpdate(double sourceTime) {
    if (_transitioning || _playingClipIndex >= _timeline.clips.length) return;
    final clip = _timeline.clips[_playingClipIndex];

    // Web's HTML5 <video>.currentTime seek is asynchronous — for a few
    // ticks after seekTo() it can still report the PREVIOUS clip's
    // position. Ignore anything reported before this clip's own start;
    // it's stale and would otherwise immediately re-trigger a jump.
    if (sourceTime < clip.startSeconds - 0.5) return;

    final offsets = _clipOffsets;

    if (sourceTime >= clip.endSeconds - 0.15) {
      final next = _playingClipIndex + 1;
      _transitioning = true;
      if (next < _timeline.clips.length) {
        _playFromClip(next).whenComplete(() => _transitioning = false);
      } else {
        _stop();
        _transitioning = false;
      }
      return;
    }

    setState(() {
      _timelinePosition =
          offsets[_playingClipIndex] + (sourceTime - clip.startSeconds);
    });
  }

  /// Seeks to an absolute position on the STITCHED timeline (e.g. from
  /// dragging the scrubber), translating it into a clip index + source time.
  void _seekTimelineTo(double timelineSeconds) {
    final offsets = _clipOffsets;
    for (var i = _timeline.clips.length - 1; i >= 0; i--) {
      if (timelineSeconds >= offsets[i]) {
        final sourceTime =
            _timeline.clips[i].startSeconds + (timelineSeconds - offsets[i]);
        _playFromClip(i, sourceSeekSeconds: sourceTime);
        setState(() => _timelinePosition = timelineSeconds);
        return;
      }
    }
  }

  // ── Clip editing ──────────────────────────────────────────────────────────

  Future<void> _persist() async {
    _timeline = _timeline.copyWith(updatedAt: DateTime.now());
    await EditTimelineStore.instance.update(_timeline);
  }

  void _reorderClip(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final clips = [..._timeline.clips];
      final moved = clips.removeAt(oldIndex);
      clips.insert(newIndex, moved);
      _timeline = _timeline.copyWith(clips: clips);
    });
    _persist();
  }

  void _deleteClip(int index) {
    setState(() {
      final clips = [..._timeline.clips]..removeAt(index);
      _timeline = _timeline.copyWith(clips: clips);
      if (_selectedClipIndex == index) _selectedClipIndex = null;
    });
    _persist();
  }

  Future<void> _addClipFromLibrary() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Importing extra clips on Web needs the file uploaded to the backend first — coming soon.'),
          backgroundColor: AppColors.accentAmber,
        ));
      }
      return;
    }

    if (file.path == null) return;

    final clip = TimelineClip(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      startSeconds: 0,
      endSeconds: 10, // placeholder — use the scissors icon to trim precisely
      importedFilePath: file.path,
    );

    setState(() {
      _timeline = _timeline.copyWith(clips: [..._timeline.clips, clip]);
    });
    _persist();
  }

  Future<void> _trimClip(int index) async {
    final clip = _timeline.clips[index];
    final url = _sourceFor(clip);
    if (url == null) return;

    final updated = await ClipTrimSheet.show(context, clip, url);
    if (updated == null || !mounted) return;

    setState(() {
      final clips = [..._timeline.clips];
      clips[index] = updated;
      _timeline = _timeline.copyWith(clips: clips);
    });
    _persist();
  }

  // ── Overlays ──────────────────────────────────────────────────────────────

  Future<void> _addOverlay(OverlayType type) async {
    if (_totalDuration <= 0) return;
    final overlay = await OverlayEditSheet.show(
      context,
      type: type,
      defaultStartSeconds: _timelinePosition,
      maxDurationSeconds: _totalDuration,
    );
    if (overlay == null) return;

    setState(() {
      _timeline =
          _timeline.copyWith(overlays: [..._timeline.overlays, overlay]);
      _selectedOverlayId = overlay.id;
    });
    _persist();
  }

  Future<void> _editOverlay(TimelineOverlay existing) async {
    final updated = await OverlayEditSheet.show(
      context,
      type: existing.type,
      existing: existing,
      defaultStartSeconds: existing.startSeconds,
      maxDurationSeconds: _totalDuration,
    );
    if (updated == null) return;

    setState(() {
      final overlays = _timeline.overlays
          .map((o) => o.id == updated.id ? updated : o)
          .toList();
      _timeline = _timeline.copyWith(overlays: overlays);
    });
    _persist();
  }

  void _dragOverlay(TimelineOverlay overlay, double dxFrac, double dyFrac) {
    setState(() {
      final overlays = _timeline.overlays.map((o) {
        if (o.id != overlay.id) return o;
        return o.copyWith(
          x: (o.x + dxFrac).clamp(0.0, 1.0),
          y: (o.y + dyFrac).clamp(0.0, 1.0),
        );
      }).toList();
      _timeline = _timeline.copyWith(overlays: overlays);
    });
  }

  void _deleteSelectedOverlay() {
    if (_selectedOverlayId == null) return;
    setState(() {
      _timeline = _timeline.copyWith(
        overlays: _timeline.overlays
            .where((o) => o.id != _selectedOverlayId)
            .toList(),
      );
      _selectedOverlayId = null;
    });
    _persist();
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _export() async {
    if (_timeline.clips.isEmpty || _exporting) return;
    if (_timeline.sourceJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This video has no backend source to render from.'),
        backgroundColor: AppColors.accentMagenta,
      ));
      return;
    }

    setState(() => _exporting = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accentCyan),
            ),
            SizedBox(width: 16),
            Text('Rendering export…',
                style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );

    try {
      final renderId = await EditorApiService.submitRender(_timeline);

      await for (final status in EditorApiService.pollRenderUntilDone(renderId)) {
        if (status['status'] == 'error') {
          throw Exception(status['error'] ?? 'Render failed');
        }
      }

      final bytes = await EditorApiService.downloadBytes(renderId);
      final safeName = _timeline.name.replaceAll(RegExp(r'[^\w\-]+'), '_');
      final result =
      await saveVideoBytes(bytes: bytes, filename: '$safeName.mp4');

      _timeline = _timeline.copyWith(
        lastRenderJobId: renderId,
        exportedAt: DateTime.now(),
      );
      await EditTimelineStore.instance.update(_timeline);

      if (mounted) {
        Navigator.pop(context); // close progress dialog
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Export saved'),
            backgroundColor: AppColors.accentGreen,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.accentMagenta,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final firstClip =
    _timeline.clips.isNotEmpty ? _timeline.clips.first : null;
    final initialUrl = firstClip != null ? _sourceFor(firstClip) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(_timeline.name,
            style:
            const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accentCyan))
                : const Icon(Icons.file_download_outlined,
                color: AppColors.accentCyan),
            tooltip: 'Export',
            onPressed: _exporting ? null : _export,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Preview + overlay layer ──────────────────────────────────────
          Expanded(
            child: Container(
              color: Colors.black,
              child: initialUrl == null
                  ? const Center(
                  child: Text('No clips yet',
                      style: TextStyle(color: AppColors.textMuted)))
                  : SizedBox.expand(
                child: Stack(
                  children: [
                    VideoPreviewPlayer(
                      key: _previewKey,
                      videoUrl: initialUrl,
                      onTimeUpdate: _onSourceTimeUpdate,
                      onReady: () => _previewKey.currentState
                          ?.seekTo(firstClip!.startSeconds),
                    ),
                    OverlayLayer(
                      overlays: _timeline.overlays,
                      currentTime: _timelinePosition,
                      selectedId: _selectedOverlayId,
                      onTap: (o) {
                        setState(() => _selectedOverlayId = o.id);
                        _editOverlay(o);
                      },
                      onDrag: _dragOverlay,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildOverlayToolbar(),
          _buildTransportBar(),
          // ── Clip track ────────────────────────────────────────────────────
          _buildClipTrack(),
        ],
      ),
    );
  }

  Widget _buildOverlayToolbar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          TextButton.icon(
            onPressed:
            _totalDuration > 0 ? () => _addOverlay(OverlayType.text) : null,
            icon: const Icon(Icons.text_fields_rounded,
                size: 16, color: AppColors.accentCyan),
            label: const Text('Add Text',
                style: TextStyle(color: AppColors.accentCyan, fontSize: 12)),
          ),
          TextButton.icon(
            onPressed: _totalDuration > 0
                ? () => _addOverlay(OverlayType.image)
                : null,
            icon: const Icon(Icons.image_outlined,
                size: 16, color: AppColors.accentCyan),
            label: const Text('Add Image',
                style: TextStyle(color: AppColors.accentCyan, fontSize: 12)),
          ),
          if (_selectedOverlayId != null)
            TextButton.icon(
              onPressed: _deleteSelectedOverlay,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.accentMagenta),
              label: const Text('Remove',
                  style:
                  TextStyle(color: AppColors.accentMagenta, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildTransportBar() {
    final maxVal = _totalDuration <= 0 ? 1.0 : _totalDuration;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.accentCyan),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Slider(
              value: _timelinePosition.clamp(0.0, maxVal),
              max: maxVal,
              activeColor: AppColors.accentCyan,
              inactiveColor: AppColors.border,
              onChanged: _totalDuration > 0 ? (v) => _seekTimelineTo(v) : null,
            ),
          ),
          Text(_fmt(_timelinePosition),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Text(' / ',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          Text(_fmt(_totalDuration),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildClipTrack() {
    const pxPerSecond = 12.0;
    const minClipWidth = 48.0;

    return Container(
      height: 96,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: _timeline.clips.length,
              onReorder: _reorderClip,
              itemBuilder: (context, index) {
                final clip = _timeline.clips[index];
                final selected = _selectedClipIndex == index;
                final width = (clip.durationSeconds * pxPerSecond)
                    .clamp(minClipWidth, 400.0);

                return ReorderableDelayedDragStartListener(
                  key: ValueKey(clip.id),
                  index: index,
                  child: GestureDetector(
                    onTap: () => _playFromClip(index),
                    child: Container(
                      width: width,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: clip.importedFilePath != null
                            ? AppColors.accentGreen.withValues(alpha: 0.15)
                            : AppColors.accentCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                          selected ? AppColors.accentCyan : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${index + 1}',
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _trimClip(index),
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.content_cut_rounded,
                                          size: 12, color: AppColors.textMuted),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _deleteClip(index),
                                    child: const Icon(Icons.close_rounded,
                                        size: 13, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(_fmt(clip.durationSeconds),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 9)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _addClipFromLibrary,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_rounded,
                  color: AppColors.accentCyan, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }
}