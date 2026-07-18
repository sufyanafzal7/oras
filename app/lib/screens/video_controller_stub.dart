// Native stub — no dart:html or dart:ui_web references here.
// All methods are no-ops; the kIsWeb guard in analysis_screen.dart
// ensures none of the video-element code paths are reached on native.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

class VideoController {
  final String viewId;
  VideoController({required this.viewId});

  double get currentTime => 0.0;

  void init({
    required VoidCallback onTimeUpdate,
    required VoidCallback onEnded,
    required VoidCallback onCanPlay,
  }) {}

  void loadFile(PlatformFile file) {}
  void play()  {}
  void pause() {}
  void seekTo(double seconds) {}
  void dispose() {}

  Widget buildView() => const SizedBox.shrink();
}