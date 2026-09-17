// Conditional export — picks the right implementation per platform.
// Same pattern as pdf_saver.dart / video_web_helper.dart.
export 'video_saver_stub.dart'
if (dart.library.io) 'video_saver_io.dart'
if (dart.library.html) 'video_saver_web.dart';