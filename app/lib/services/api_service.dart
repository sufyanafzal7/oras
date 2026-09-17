import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/procedure.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static String get baseUrl => _base;

  static String get _base {
    if (kIsWeb) return 'http://127.0.0.1:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.137.1:5000';   // PC hotspot IP
    }
    return 'http://127.0.0.1:5000';
  }

  static String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return 'android';
      case TargetPlatform.iOS:     return 'ios';
      case TargetPlatform.windows: return 'windows';
      case TargetPlatform.macOS:   return 'macos';
      case TargetPlatform.linux:   return 'linux';
      default:                     return 'unknown';
    }
  }

  // ── Health check ──────────────────────────────────────────────────────────
  static Future<bool> isBackendAlive() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Submit video — works on web AND native ─────────────────────────────────
  // Takes a PlatformFile directly so we can use bytes on web, path on native.
  static Future<String> submitVideo(PlatformFile file) async {
    final req = http.MultipartRequest('POST', Uri.parse('$_base/analyze'));
    req.fields['platform'] = _platform;

    // AFTER:
    if (kIsWeb) {
      // Use fromBytes only if file is under 500 MB to avoid browser memory crash.
      // For larger files on web, we cannot stream — this is a browser limitation.
      // Show a clear error message instead of a silent crash.
      if (file.bytes == null || file.size > 500 * 1024 * 1024) {
        throw Exception(
          'Web uploads are limited to 500 MB. '
              'For larger videos, use the Desktop app.',
        );
      }
      req.files.add(http.MultipartFile.fromBytes(
        'video',
        file.bytes!,
        filename: file.name,
        contentType: MediaType('video', 'mp4'),
      ));
    } else {
      req.files.add(await http.MultipartFile.fromPath(
        'video',
        file.path!,
        filename: file.name,
      ));
    }

    final streamed = await req.send();
    final body     = await streamed.stream.bytesToString();
    final data     = jsonDecode(body) as Map<String, dynamic>;

    if (streamed.statusCode != 202) {
      throw Exception(data['error'] ?? 'Upload failed (${streamed.statusCode})');
    }
    return data['job_id'] as String;
  }

  // ── Poll one job status ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final res = await http
        .get(Uri.parse('$_base/status/$jobId'))
        .timeout(const Duration(seconds: 5));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Stream updates until done or error ───────────────────────────────────
  static Stream<Map<String, dynamic>> pollUntilDone(String jobId) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 2));
      final data = await getJobStatus(jobId);
      yield data;
      if (data['status'] == 'done' || data['status'] == 'error') break;
    }
  }

  // ── Convert backend result → Procedure ───────────────────────────────────
  static Procedure resultToProcedure(Map<String, dynamic> jobData, String title) {
    final raw = jobData['result'] as Map<String, dynamic>;
    return Procedure(
      id:            DateTime.now().millisecondsSinceEpoch.toString(),
      title:         title,
      surgeonName:   'ORAS Auto-Analysis',
      date:          DateTime.now(),
      status:        ProcedureStatus.completed,
      duration:      Duration(seconds: (raw['duration'] as num).toInt()),
      phaseTimeline: (raw['phase_timeline'] as List)
          .map((p) => PhaseEntry.fromJson(p as Map<String, dynamic>))
          .toList(),
      toolsDetected: (raw['tools_detected'] as List)
          .map((t) => ToolEntry.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
  /// Returns the URL to stream the video for a given job.
  /// Works on all platforms — native uses it too so code is unified.
  static String videoUrl(String jobId) => '$_base/video/$jobId';

  static Future<bool> isVideoAvailable(String jobId) async {
    try {
      final res = await http
          .head(Uri.parse('$_base/video/$jobId'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }

  }
  // ── Editing-timeline protection ──────────────────────────────────────────
  // Called by EditTimelineStore whenever a video gains/loses its first/last
  // saved editing timeline, so the web-only rolling upload limit never
  // deletes a source file a timeline still depends on.

  static Future<void> protectJob(String jobId) async {
    try {
      await http
          .post(Uri.parse('$_base/jobs/$jobId/protect'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best-effort — if this fails the web cap may evict the video early,
      // but it never blocks the local editing flow.
    }
  }

  static Future<void> unprotectJob(String jobId) async {
    try {
      await http
          .post(Uri.parse('$_base/jobs/$jobId/unprotect'))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}