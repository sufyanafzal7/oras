import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../models/procedure.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static String get _base {
    if (kIsWeb) return 'http://127.0.0.1:5000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.137.1:5000';   // PC hotspot IP
    }
    return 'http://127.0.0.1:5000';
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

    if (kIsWeb) {
      req.files.add(http.MultipartFile.fromBytes(
        'video',
        file.bytes!,
        filename: file.name,
        contentType: MediaType('video', 'mp4'),  // explicit MIME type
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
}