// Web PDF save — the browser handles the actual download prompt.

import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<String?> savePdfBytes({
  required List<int> bytes,
  required String filename,
}) async {
  await Printing.sharePdf(
    bytes: Uint8List.fromList(bytes),
    filename: filename,
  );
  return 'Downloaded';
}