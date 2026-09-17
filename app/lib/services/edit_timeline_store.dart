import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/edit_timeline.dart';
import 'api_service.dart';

/// Persistent store for every saved video-editing timeline, across all
/// source videos. Backed by SharedPreferences (one JSON list — same
/// pattern as ProcedureStore). Timelines are filtered by
/// sourceProcedureId at read time: the Video Editing tab only ever
/// shows the slice belonging to the currently selected procedure.
///
/// Cap: [kMaxTimelinesPerVideo] timelines per source video.
class EditTimelineStore extends ChangeNotifier {
  EditTimelineStore._();
  static final EditTimelineStore instance = EditTimelineStore._();

  static const _kKey = 'oras_edit_timelines_v1';
  static const kMaxTimelinesPerVideo = 10;

  List<EditTimeline> _timelines = [];

  List<EditTimeline> get all => List.unmodifiable(_timelines);

  /// Timelines belonging to one source video, most recently updated first.
  List<EditTimeline> timelinesFor(String sourceProcedureId) => _timelines
      .where((t) => t.sourceProcedureId == sourceProcedureId)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  int countFor(String sourceProcedureId) =>
      _timelines.where((t) => t.sourceProcedureId == sourceProcedureId).length;

  bool canAddMoreFor(String sourceProcedureId) =>
      countFor(sourceProcedureId) < kMaxTimelinesPerVideo;

  // ── Init (called once from main) ──────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_kKey) ?? [];
    _timelines = raw
        .map((s) {
      try {
        return EditTimeline.decode(s);
      } catch (_) {
        return null;
      }
    })
        .whereType<EditTimeline>()
        .toList();
    notifyListeners();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Adds a new timeline. Check [canAddMoreFor] before calling from the
  /// UI — the 10-per-video cap is enforced here as a hard guard too.
  Future<void> add(EditTimeline timeline) async {
    if (!canAddMoreFor(timeline.sourceProcedureId)) {
      throw StateError(
          'Max $kMaxTimelinesPerVideo timelines reached for this video.');
    }
    final isFirstForSource = countFor(timeline.sourceProcedureId) == 0;

    _timelines.insert(0, timeline);
    await _persist();
    notifyListeners();

    // First timeline on this video — tell the backend not to purge its
    // source file under the web-only rolling upload limit.
    if (isFirstForSource && timeline.sourceJobId != null) {
      ApiService.protectJob(timeline.sourceJobId!);
    }
  }

  Future<void> update(EditTimeline timeline) async {
    final idx = _timelines.indexWhere((t) => t.id == timeline.id);
    if (idx == -1) return;
    _timelines[idx] = timeline;
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final idx = _timelines.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final removed = _timelines[idx];

    _timelines.removeAt(idx);
    await _persist();
    notifyListeners();

    // Last timeline for this source video — safe to let the backend
    // purge it again under the web-only rolling upload limit.
    final stillHasOthers = _timelines
        .any((t) => t.sourceProcedureId == removed.sourceProcedureId);
    if (!stillHasOthers && removed.sourceJobId != null) {
      ApiService.unprotectJob(removed.sourceJobId!);
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _kKey, _timelines.map((t) => t.encode()).toList());
  }
}