// Web-only implementation using dart:html + dart:ui_web.
// Only compiled on web targets via the conditional import in analysis_screen.dart:
//   import 'video_web_helper.dart'
//       if (dart.library.io) 'video_web_helper_stub.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

class WebVideoHelper {
  html.VideoElement? _el;
  String? _objectUrl;
  final String _viewId =
      'oras-web-video-${DateTime.now().millisecondsSinceEpoch}';

  bool _registered = false;

  void init({
    required VoidCallback onTimeUpdate,
    required VoidCallback onEnded,
    required VoidCallback onCanPlay,
  }) {
    _el = html.VideoElement()
      ..style.width           = '100%'
      ..style.height          = '100%'
      ..style.objectFit       = 'contain'
      ..style.backgroundColor = '#0A0D12'
      ..controls              = false;

    if (!_registered) {
      ui_web.platformViewRegistry
          .registerViewFactory(_viewId, (_) => _el!);
      _registered = true;
    }

    _el!.onTimeUpdate.listen((_) => onTimeUpdate());
    _el!.onEnded.listen((_) => onEnded());
    _el!.onCanPlay.listen((_) => onCanPlay());
  }

  double get currentTime => _el?.currentTime.toDouble() ?? 0.0;

  void loadFile(PlatformFile file) {
    if (_el == null || file.bytes == null) return;
    _revokeOldUrl();
    final blob = html.Blob([file.bytes!]);
    _objectUrl = html.Url.createObjectUrlFromBlob(blob);
    _el!.src = _objectUrl!;
  }

  void loadUrl(String url) {
    if (_el == null) return;
    _revokeOldUrl();
    _el!.src = url;
  }

  void play()  => _el?.play();
  void pause() => _el?.pause();

  void seekTo(double seconds) {
    if (_el != null) _el!.currentTime = seconds;
  }

  Widget buildView() => HtmlElementView(viewType: _viewId);

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
}