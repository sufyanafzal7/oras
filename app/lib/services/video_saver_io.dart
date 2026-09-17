// Native (Android / iOS / Windows / Linux / macOS) video save.
// file_picker's saveFile supports all of these targets directly, unlike
// `printing` (PDF-only), so there's no separate mobile-vs-desktop split
// here the way pdf_saver_io.dart needs one.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves the exported video, returning the saved path, or null if the
/// user cancelled the save dialog.
Future<String?> saveVideoBytes({
  required List<int> bytes,
  required String filename,
}) async {
  final data = Uint8List.fromList(bytes);

  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Exported Video',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['mp4'],
    bytes: data, // required for platforms (mobile) that write internally
  );

  if (path == null) return null; // user cancelled

  // Desktop returns a path without writing the bytes itself — write
  // explicitly if that's the case here. Harmless no-op where file_picker
  // already wrote the file using `bytes` above.
  final file = File(path);
  if (!(await file.exists()) || (await file.length()) == 0) {
    await file.writeAsBytes(data, flush: true);
  }
  return path;
}