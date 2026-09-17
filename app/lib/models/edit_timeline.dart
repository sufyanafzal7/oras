import 'dart:convert';
import 'timeline_clip.dart';
import 'timeline_overlay.dart';

/// One saved video-editing project. Always scoped to a single source
/// [StoredProcedure] via [sourceProcedureId]. Persisted by
/// EditTimelineStore (SharedPreferences) — mirrors StoredProcedure's
/// own encode/decode pattern.
class EditTimeline {
  final String  id;
  final String  sourceProcedureId; // StoredProcedure.id — local scoping key
  final String? sourceJobId;       // StoredProcedure.jobId — backend job, for protect + render
  final String? sourceFilePath;    // StoredProcedure.filePath — native fallback when no jobId
  final String  sourceFileName;    // display only, e.g. "surgery_04.mp4"
  final String  name;
  final List<TimelineClip>    clips;
  final List<TimelineOverlay> overlays;
  final DateTime  createdAt;
  final DateTime  updatedAt;
  final String?   lastRenderJobId; // backend render job, for re-polling/downloading
  final DateTime? exportedAt;

  const EditTimeline({
    required this.id,
    required this.sourceProcedureId,
    this.sourceJobId,
    this.sourceFilePath,
    required this.sourceFileName,
    required this.name,
    this.clips = const [],
    this.overlays = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastRenderJobId,
    this.exportedAt,
  });

  double get totalDurationSeconds =>
      clips.fold(0.0, (s, c) => s + c.durationSeconds);

  String get formattedDuration {
    final t = totalDurationSeconds;
    final m = (t ~/ 60).toString().padLeft(2, '0');
    final s = (t.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get isExported => exportedAt != null;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':                id,
    'sourceProcedureId': sourceProcedureId,
    'sourceJobId':       sourceJobId,
    'sourceFilePath':    sourceFilePath,
    'sourceFileName':    sourceFileName,
    'name':              name,
    'clips':             clips.map((c) => c.toJson()).toList(),
    'overlays':          overlays.map((o) => o.toJson()).toList(),
    'createdAt':         createdAt.toIso8601String(),
    'updatedAt':         updatedAt.toIso8601String(),
    'lastRenderJobId':   lastRenderJobId,
    'exportedAt':        exportedAt?.toIso8601String(),
  };

  factory EditTimeline.fromJson(Map<String, dynamic> j) => EditTimeline(
    id:                j['id']               as String,
    sourceProcedureId: j['sourceProcedureId'] as String,
    sourceJobId:       j['sourceJobId']        as String?,
    sourceFilePath:    j['sourceFilePath']     as String?,
    sourceFileName:    j['sourceFileName']     as String,
    name:              j['name']              as String,
    clips: (j['clips'] as List? ?? [])
        .map((c) => TimelineClip.fromJson(c as Map<String, dynamic>))
        .toList(),
    overlays: (j['overlays'] as List? ?? [])
        .map((o) => TimelineOverlay.fromJson(o as Map<String, dynamic>))
        .toList(),
    createdAt:       DateTime.parse(j['createdAt'] as String),
    updatedAt:       DateTime.parse(j['updatedAt'] as String),
    lastRenderJobId: j['lastRenderJobId'] as String?,
    exportedAt: j['exportedAt'] != null
        ? DateTime.parse(j['exportedAt'] as String)
        : null,
  );

  EditTimeline copyWith({
    String?                name,
    List<TimelineClip>?    clips,
    List<TimelineOverlay>? overlays,
    DateTime?               updatedAt,
    String?                 lastRenderJobId,
    DateTime?               exportedAt,
  }) => EditTimeline(
    id:                id,
    sourceProcedureId: sourceProcedureId,
    sourceJobId:       sourceJobId,
    sourceFileName:    sourceFileName,
    name:              name ?? this.name,
    clips:             clips ?? this.clips,
    overlays:          overlays ?? this.overlays,
    createdAt:         createdAt,
    updatedAt:         updatedAt ?? this.updatedAt,
    lastRenderJobId:   lastRenderJobId ?? this.lastRenderJobId,
    exportedAt:        exportedAt ?? this.exportedAt,
  );

  String encode() => jsonEncode(toJson());

  static EditTimeline decode(String s) =>
      EditTimeline.fromJson(jsonDecode(s) as Map<String, dynamic>);
}