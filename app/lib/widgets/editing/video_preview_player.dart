import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../screens/video_controller.dart';
import '../../screens/video_web_helper.dart'
if (dart.library.io) '../../screens/video_web_helper_stub.dart';

/// Thin cross-platform video surface used by the editor's preview pane.
/// Wraps VideoController (native, media_kit) / WebVideoHelper (web,
/// dart:html) behind one API — same conditional-import split already
/// used elsewhere in the app (see video_web_helper_stub.dart).
///
/// Control it imperatively via a GlobalKey<VideoPreviewPlayerState>:
/// play(), pause(), seekTo(seconds), load(url).
class VideoPreviewPlayer extends StatefulWidget {
  final String videoUrl;
  final ValueChanged<double>? onTimeUpdate;
  final VoidCallback? onEnded;
  final VoidCallback? onReady;

  const VideoPreviewPlayer({
    super.key,
    required this.videoUrl,
    this.onTimeUpdate,
    this.onEnded,
    this.onReady,
  });

  @override
  State<VideoPreviewPlayer> createState() => VideoPreviewPlayerState();
}

class VideoPreviewPlayerState extends State<VideoPreviewPlayer> {
  VideoController? _native;
  WebVideoHelper? _web;
  bool _ready = false;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _setup(widget.videoUrl);
  }

  Future<void> _setup(String url) async {
    _currentUrl = url;
    if (kIsWeb) {
      _web = WebVideoHelper();
      _web!.init(
        onTimeUpdate: () => widget.onTimeUpdate?.call(_web!.currentTime),
        onEnded: () => widget.onEnded?.call(),
        onCanPlay: _markReady,
      );
      _web!.loadUrl(url);
    } else {
      _native = VideoController();
      _native!.init(
        onTimeUpdate: () =>
            widget.onTimeUpdate?.call(_native!.currentTimeSeconds),
        onEnded: () => widget.onEnded?.call(),
        onCanPlay: _markReady,
      );
      await _native!.loadUrl(url);
    }
  }

  void _markReady() {
    if (!mounted) return;
    setState(() => _ready = true);
    widget.onReady?.call();
  }

  /// Swaps the loaded source — used when playback crosses into a clip
  /// that was imported from a different file than the timeline's
  /// primary source video. No-op if [url] is already loaded.
  Future<void> load(String url) async {
    if (url == _currentUrl) return;
    setState(() => _ready = false);
    if (kIsWeb) {
      _web?.dispose();
    } else {
      await _native?.dispose();
    }
    _web = null;
    _native = null;
    await _setup(url);
  }

  void play() => kIsWeb ? _web?.play() : _native?.play();

  void pause() => kIsWeb ? _web?.pause() : _native?.pause();

  void seekTo(double seconds) =>
      kIsWeb ? _web?.seekTo(seconds) : _native?.seekTo(seconds);

  double get currentTime =>
      kIsWeb ? (_web?.currentTime ?? 0.0) : (_native?.currentTimeSeconds ?? 0.0);

  double get sourceDurationSeconds =>
      kIsWeb ? (_web?.duration ?? 0.0) : (_native?.durationSeconds ?? 0.0);

  @override
  void dispose() {
    _web?.dispose();
    _native?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return kIsWeb ? _web!.buildView() : _native!.buildView();
  }
}