// Unified native video controller using the video_player package.
// Handles Android (contentUri) and Windows/Desktop (file path).
// NOT used on web — web video goes through WebVideoHelper (dart:html).

import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

class VideoController {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  VoidCallback? _onTimeUpdate;
  VoidCallback? _onEnded;
  VoidCallback? _onCanPlay;

  // Call once from initState on all platforms (safe no-op on web since
  // analysis_screen.dart only calls loadFile/play/pause on native).
  void init({
    required VoidCallback onTimeUpdate,
    required VoidCallback onEnded,
    required VoidCallback onCanPlay,
  }) {
    _onTimeUpdate = onTimeUpdate;
    _onEnded      = onEnded;
    _onCanPlay    = onCanPlay;
  }

  // Async — must be awaited before calling play/pause/seekTo.
  Future<void> loadFile(PlatformFile file) async {
    await _disposeController();

    late VideoPlayerController c;

    if (Platform.isAndroid || Platform.isIOS) {
      // file_picker on Android returns a content:// URI in file.path
      c = VideoPlayerController.contentUri(
          Uri.parse(file.path ?? ''));
    } else {
      // Windows, macOS, Linux — real filesystem path
      c = VideoPlayerController.file(File(file.path!));
    }

    _ctrl = c;

    c.addListener(() {
      if (!_initialized) return;
      _onTimeUpdate?.call();
      final val = c.value;
      if (val.position >= val.duration &&
          val.duration.inMilliseconds > 0 &&
          !val.isPlaying) {
        _onEnded?.call();
      }
    });

    await c.initialize();
    _initialized = true;
    _onCanPlay?.call();
  }

  // Position in seconds (double).
  double get currentTimeSeconds =>
      (_ctrl?.value.position.inMilliseconds ?? 0) / 1000.0;

  // Aspect ratio for AspectRatio widget — defaults to 16:9 before init.
  double get aspectRatio =>
      (_initialized && _ctrl != null)
          ? _ctrl!.value.aspectRatio
          : 16 / 9;

  bool get isInitialized =>
      _initialized && (_ctrl?.value.isInitialized ?? false);

  void play()  => _ctrl?.play();
  void pause() => _ctrl?.pause();

  void seekTo(double seconds) {
    _ctrl?.seekTo(
        Duration(milliseconds: (seconds * 1000).toInt()));
  }

  // Returns the VideoPlayer widget; SizedBox.shrink() if not ready.
  Widget buildView() {
    if (!isInitialized || _ctrl == null) return const SizedBox.shrink();
    return VideoPlayer(_ctrl!);
  }

  Future<void> _disposeController() async {
    _initialized = false;
    await _ctrl?.dispose();
    _ctrl = null;
  }

  Future<void> dispose() async {
    await _disposeController();
  }
}