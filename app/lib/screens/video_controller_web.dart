// Web implementation — dart:html and dart:ui_web are only compiled on web targets.
// Do NOT import this file directly; import video_controller.dart instead.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

class VideoController {
  html.VideoElement? _el;
  String? _objectUrl;
  final String viewId;

  VideoController({required this.viewId});

  /// Call once from initState on web.
  void init({
    required VoidCallback onTimeUpdate,
    required VoidCallback onEnded,
    required VoidCallback onCanPlay,
  }) {
    _el = html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = '#0A0D12'
      ..controls = false;

    ui_web.platformViewRegistry.registerViewFactory(viewId, (_) => _el!);

    _el!.onTimeUpdate.listen((_) => onTimeUpdate());
    _el!.onEnded.listen((_) => onEnded());
    _el!.onCanPlay.listen((_) => onCanPlay());
  }

  double get currentTime => _el?.currentTime.toDouble() ?? 0.0;

  void loadFile(PlatformFile file) {
    if (_el == null) return;
    _revokeOldUrl();
    final blob = html.Blob([file.bytes!]);
    _objectUrl = html.Url.createObjectUrlFromBlob(blob);
    _el!.src = _objectUrl!;
  }

  void play()  => _el?.play();
  void pause() => _el?.pause();
  void seekTo(double seconds) {
    if (_el != null) _el!.currentTime = seconds;
  }

  void dispose() {
    _el?.pause();
    _revokeOldUrl();
    _el = null;
  }

  void _revokeOldUrl() {
    if (_objectUrl != null) {
      html.Url.revokeObjectUrl(_objectUrl!);
      _objectUrl = null;
    }
  }

  /// Returns the HtmlElementView widget that renders the video.
  Widget buildView() => HtmlElementView(viewType: viewId);
}