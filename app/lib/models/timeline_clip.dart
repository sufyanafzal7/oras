/// A single trimmed segment cut from the source procedure's video,
/// identified by its in/out points in the ORIGINAL video's timeline.
/// Order within an [EditTimeline] is simply its position in the
/// timeline's `clips` list — reordering is a list operation, no
/// separate order field needed.
class TimelineClip {
  final String id;
  final double startSeconds; // in-point, seconds into the source video
  final double endSeconds;   // out-point, seconds into the source video
  final String? importedFilePath; // set only for clips added via "+" in the
  // editor from a separate local video file;
  // null means "use the timeline's primary
  // source video" (the normal case).

  const TimelineClip({
    required this.id,
    required this.startSeconds,
    required this.endSeconds,
    this.importedFilePath,
  });

  double get durationSeconds =>
      (endSeconds - startSeconds).clamp(0.0, double.infinity);

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':               id,
    'startSeconds':     startSeconds,
    'endSeconds':       endSeconds,
    'importedFilePath': importedFilePath,
  };

  factory TimelineClip.fromJson(Map<String, dynamic> j) => TimelineClip(
    id:               j['id']            as String,
    startSeconds:     (j['startSeconds'] as num).toDouble(),
    endSeconds:       (j['endSeconds']   as num).toDouble(),
    importedFilePath: j['importedFilePath'] as String?,
  );

  TimelineClip copyWith({
    double? startSeconds,
    double? endSeconds,
    String? importedFilePath,
  }) =>
      TimelineClip(
        id:               id,
        startSeconds:     startSeconds ?? this.startSeconds,
        endSeconds:       endSeconds   ?? this.endSeconds,
        importedFilePath: importedFilePath ?? this.importedFilePath,
      );
}