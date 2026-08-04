// Native (non-web) PDF save/share.
//
// Android / iOS  -> system share sheet via `printing` (best UX on mobile,
//                    lets the user save to Files / Drive / send it on).
// Windows / Linux / macOS -> native "Save As" dialog via file_picker,
//                    then the bytes are written straight to disk.
//                    (Printing.sharePdf has no working share/save target
//                    on Windows, so it silently no-ops there — this is
//                    why PDFs never appeared before.)

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

/// Saves or shares a PDF depending on platform.
/// Returns:
///   - the saved file path on Desktop
///   - the string 'Shared' on Android/iOS
///   - null if the user cancelled the save dialog
Future<String?> savePdfBytes({
  required List<int> bytes,
  required String filename,
}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: filename,
    );
    return 'Shared';
  }

  // Desktop: Windows / Linux / macOS
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Report PDF',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (path == null) return null; // user cancelled the dialog

  final outPath = path.toLowerCase().endsWith('.pdf') ? path : '$path.pdf';
  final file = File(outPath);
  await file.writeAsBytes(bytes, flush: true);
  return outPath;
}