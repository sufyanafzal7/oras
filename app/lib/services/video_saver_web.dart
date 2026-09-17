// Web video save — triggers a browser download via an object URL,
// same Blob/AnchorElement pattern already used for picked files in
// video_web_helper.dart.

import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<String?> saveVideoBytes({
  required List<int> bytes,
  required String filename,
}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'video/mp4');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded';
}