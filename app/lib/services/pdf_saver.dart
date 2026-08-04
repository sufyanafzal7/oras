// Conditional export — picks the right implementation per platform.
// Same pattern as video_web_helper.dart / video_web_helper_stub.dart.
//
// dart.library.io  -> true on Windows / Linux / macOS / Android / iOS
// dart.library.html -> true on Web
//
// Default (no condition matched) falls back to the stub, which should
// never actually be reached on a real Flutter target.
export 'pdf_saver_stub.dart'
if (dart.library.io) 'pdf_saver_io.dart'
if (dart.library.html) 'pdf_saver_web.dart';