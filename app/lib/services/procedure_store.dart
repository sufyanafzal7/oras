import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stored_procedure.dart';

/// Persistent store for every video that has been analyzed.
/// Backed by SharedPreferences (JSON list).  Works on all 4 platforms.
///
/// Usage:
///   await ProcedureStore.instance.init();   // call once in main()
///   ProcedureStore.instance.add(record);    // after each analysis
///   ProcedureStore.instance.procedures;     // read current list
///   ProcedureStore.instance.addListener();  // rebuild on change
class ProcedureStore extends ChangeNotifier {
  ProcedureStore._();
  static final ProcedureStore instance = ProcedureStore._();

  static const _kKey = 'oras_procedures_v1';

  List<StoredProcedure> _procedures = [];

  /// All stored procedures, newest first.
  List<StoredProcedure> get procedures =>
      List.unmodifiable(_procedures);

  // ── Init (called once from main) ──────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_kKey) ?? [];
    _procedures = raw
        .map((s) {
      try {
        return StoredProcedure.decode(s);
      } catch (_) {
        return null;
      }
    })
        .whereType<StoredProcedure>()
        .toList()
      ..sort((a, b) => b.processedAt.compareTo(a.processedAt));
    notifyListeners();
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> add(StoredProcedure record) async {
    _procedures.insert(0, record); // newest first
    await _persist();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _procedures.removeWhere((p) => p.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _procedures.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    notifyListeners();
  }

  // ── Derived stats used by Dashboard ──────────────────────────────────────

  /// Total runtime of all processed videos in seconds.
  double get totalRuntimeSeconds =>
      _procedures.fold(0.0, (s, p) => s + p.durationSeconds);

  String get formattedTotalRuntime {
    final t = totalRuntimeSeconds;
    final h = (t ~/ 3600);
    final m = ((t % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (t.toInt() % 60).toString().padLeft(2, '0');
    return h > 0 ? '${h}h $m:$s' : '$m:$s';
  }

  int get totalCount => _procedures.length;

  /// Most frequently occurring dominant phase across all procedures.
  String get globalDominantPhase {
    if (_procedures.isEmpty) return '—';
    final freq = <String, int>{};
    for (final p in _procedures) {
      freq[p.dominantPhase] = (freq[p.dominantPhase] ?? 0) + 1;
    }
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Most frequently occurring dominant tool across all procedures.
  String get globalDominantTool {
    if (_procedures.isEmpty) return '—';
    final freq = <String, int>{};
    for (final p in _procedures) {
      freq[p.dominantTool] = (freq[p.dominantTool] ?? 0) + 1;
    }
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get averageDurationSeconds => _procedures.isEmpty
      ? 0.0
      : totalRuntimeSeconds / _procedures.length;

  String get formattedAverageDuration {
    final t = averageDurationSeconds;
    final m = (t ~/ 60).toString().padLeft(2, '0');
    final s = (t.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, _procedures.map((p) => p.encode()).toList());
  }
}