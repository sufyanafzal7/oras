/// Fallback stub — real platforms always resolve to
/// pdf_saver_io.dart or pdf_saver_web.dart instead.
Future<String?> savePdfBytes({
  required List<int> bytes,
  required String filename,
}) async {
  throw UnsupportedError('PDF saving is not supported on this platform.');
}