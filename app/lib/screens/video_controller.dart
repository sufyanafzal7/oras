// Native video controller using media_kit.
// Supports Android, Windows Desktop, macOS, Linux.
// NOT used on web — web video goes through WebVideoHelper (dart:html).

import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart'
as mk show VideoController, Video;

class VideoController {
  Player?          _player;
  mk.VideoController? _mkCtrl;
  bool _initialized = false;

  VoidCallback? _onTimeUpdate;
  VoidCallback? _onEnded;
  VoidCallback? _onCanPlay;

  void init({
    required VoidCallback onTimeUpdate,
    required VoidCallback onEnded,
    required VoidCallback onCanPlay,
  }) {
    _onTimeUpdate = onTimeUpdate;
    _onEnded      = onEnded;
    _onCanPlay    = onCanPlay;

    _player = Player();
    _mkCtrl = mk.VideoController(_player!);

    _player!.stream.position.listen((_) => _onTimeUpdate?.call());
    _player!.stream.completed.listen((done) {
      if (done) _onEnded?.call();
    });
  }

  Future<void> loadFile(PlatformFile file) async {
    if (_player == null) return;
    _initialized = false;
    final path = file.path!;
    // file:/// prefix required on Windows; works on all platforms
    await _player!.open(Media('file:///$path'), play: false);
    _initialized = true;
    _onCanPlay?.call();
  }

  Future<void> loadUrl(String url) async {
    if (_player == null) return;
    _initialized = false;
    await _player!.open(Media(url), play: false);
    _initialized = true;
    _onCanPlay?.call();
  }

  double get currentTimeSeconds =>
      (_player?.state.position.inMilliseconds ?? 0) / 1000.0;

  double get aspectRatio {
    final w = _player?.state.width;
    final h = _player?.state.height;
    if (w != null && h != null && h > 0) return w / h;
    return 16 / 9;
  }

  bool get isInitialized => _initialized;

  void play()  => _player?.play();
  void pause() => _player?.pause();

  void seekTo(double seconds) =>
      _player?.seek(Duration(milliseconds: (seconds * 1000).toInt()));

  Widget buildView() {
    if (!_initialized || _mkCtrl == null) return const SizedBox.shrink();
    return mk.Video(controller: _mkCtrl!);
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _mkCtrl = null;
  }
}