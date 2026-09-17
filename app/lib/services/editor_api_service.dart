import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/edit_timeline.dart';
import '../models/timeline_overlay.dart';
import 'api_service.dart';

/// Talks to the backend's /edit/* rendering endpoints — same job/poll
/// shape as ApiService's /analyze + /status.
class EditorApiService {
  static String get _base => ApiService.baseUrl;

  // ── Submit a render job ──────────────────────────────────────────────────

  static Future<String> submitRender(EditTimeline timeline) async {
    final req =
    http.MultipartRequest('POST', Uri.parse('$_base/edit/render'));

    req.fields['job_id'] = timeline.sourceJobId ?? '';
    req.fields['edit_plan'] = jsonEncode({
      'clips': timeline.clips
          .map((c) => {
        'startSeconds': c.startSeconds,
        'endSeconds': c.endSeconds,
      })
          .toList(),
      'overlays': timeline.overlays
          .map((o) => {
        'type': o.type.wire,
        'content': o.type == OverlayType.text ? o.content : null,
        'startSeconds': o.startSeconds,
        'durationSeconds': o.durationSeconds,
        'x': o.x,
        'y': o.y,
        'fontSize': o.fontSize,
        'colorHex': o.colorHex,
      })
          .toList(),
    });

    // Locally-imported clip files and image overlays live only on this
    // device — upload them alongside the plan so the backend can render
    // them. (Web can't reach local file paths at all; those pieces are
    // skipped there until browser-side pre-upload lands.)
    if (!kIsWeb) {
      for (var i = 0; i < timeline.clips.length; i++) {
        final path = timeline.clips[i].importedFilePath;
        if (path != null) {
          req.files
              .add(await http.MultipartFile.fromPath('imported_$i', path));
        }
      }
      for (var i = 0; i < timeline.overlays.length; i++) {
        final ov = timeline.overlays[i];
        if (ov.type == OverlayType.image) {
          req.files.add(await http.MultipartFile.fromPath(
              'overlay_image_$i', ov.content));
        }
      }
    }

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    if (streamed.statusCode != 202) {
      throw Exception(data['error'] ?? 'Render request failed');
    }
    return data['render_job_id'] as String;
  }

  // ── Poll status ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getRenderStatus(String renderId) async {
    final res = await http
        .get(Uri.parse('$_base/edit/status/$renderId'))
        .timeout(const Duration(seconds: 5));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Stream<Map<String, dynamic>> pollRenderUntilDone(
      String renderId) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      final data = await getRenderStatus(renderId);
      yield data;
      if (data['status'] == 'done' || data['status'] == 'error') break;
    }
  }

  // ── Download the finished file ───────────────────────────────────────────

  static String downloadUrl(String renderId) =>
      '$_base/edit/download/$renderId';

  static Future<List<int>> downloadBytes(String renderId) async {
    final res = await http.get(Uri.parse(downloadUrl(renderId)));
    if (res.statusCode != 200) {
      throw Exception('Download failed (${res.statusCode})');
    }
    return res.bodyBytes;
  }
}