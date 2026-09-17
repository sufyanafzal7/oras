/// Fallback stub — real platforms always resolve to
/// video_saver_io.dart or video_saver_web.dart instead.
Future<String?> saveVideoBytes({
  required List<int> bytes,
  required String filename,
}) async {
  throw UnsupportedError('Video saving is not supported on this platform.');
}