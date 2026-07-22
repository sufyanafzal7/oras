// Native stub — imported instead of video_web_helper.dart on Android/Windows.
// No dart:html or dart:ui_web references. All methods are no-ops.
// The kIsWeb guard in analysis_screen.dart ensures none of these
// code paths are ever reached at runtime on native targets.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

class WebVideoHelper {
  double get currentTime => 0.0;

  void init({
    required VoidCallback onTimeUpdate,
    required VoidCallback onEnded,
    required VoidCallback onCanPlay,
  }) {}

  void loadFile(PlatformFile file) {}
  void loadUrl(String url) {}
  void play()  {}
  void pause() {}
  void seekTo(double seconds) {}
  void dispose() {}

  Widget buildView() => const SizedBox.shrink();
}