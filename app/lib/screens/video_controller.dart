// This is the ONLY file analysis_screen.dart imports for video functionality.
// The conditional export ensures dart:html / dart:ui_web are NEVER seen by
// the native (Android / Windows / macOS) compiler toolchain.

export 'video_controller_stub.dart'
if (dart.library.html) 'video_controller_web.dart';