// Native stub — dart:html is only available on web.
// All members here are no-ops so the analyzer and compiler are satisfied.
// At runtime on non-web targets, the conditional import picks this file,
// but none of the HTML code paths are ever reached (all gated on kIsWeb).
/*
library html_stub;

class Blob {
  // ignore: avoid_unused_constructor_parameters
  Blob(List<dynamic> _);
}

class Url {
  static String createObjectUrlFromBlob(Blob _) => '';
}

class VideoElement {
  String src = '';
  double currentTime = 0.0;
  bool controls = false;

  // Style stub
  final _StyleStub style = _StyleStub();

  // Event streams — return empty streams so listen() calls compile.
  Stream<dynamic> get onTimeUpdate  => const Stream.empty();
  Stream<dynamic> get onEnded       => const Stream.empty();
  Stream<dynamic> get onCanPlay     => const Stream.empty();

  void pause() {}
  Future<void> play() async {}
}

class _StyleStub {
  String width           = '';
  String height          = '';
  String objectFit       = '';
  String backgroundColor = '';
}
*/
