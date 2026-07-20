import 'package:flutter/foundation.dart';

/// Shared singleton written by the Upload tab when analysis completes,
/// read by the Analysis tab to populate all graphs and diagrams.
/// Uses ChangeNotifier so any listener rebuilds automatically.
class AnalysisState extends ChangeNotifier {
  AnalysisState._();
  static final AnalysisState instance = AnalysisState._();

  // ── Raw backend result ────────────────────────────────────────────────────
  Map<String, dynamic>? _result;
  Map<String, dynamic>? _cachedRaw;

  bool get hasResult => _result != null;
  Map<String, dynamic>? get lastRaw => _cachedRaw;

  // ── Parsed fields ─────────────────────────────────────────────────────────
  double             get totalDuration  => (_result?['duration']  as num?)?.toDouble() ?? 0.0;
  double             get fps            => (_result?['fps']       as num?)?.toDouble() ?? 25.0;
  List<PhaseSegment> get phaseTimeline  => _phaseTimeline;
  List<ToolResult>   get toolsDetected  => _toolsDetected;

  List<PhaseSegment> _phaseTimeline = [];
  List<ToolResult>   _toolsDetected = [];

  // ── Write (called by Upload tab) ──────────────────────────────────────────
  void setResult(Map<String, dynamic> raw) {
    _result = raw;
    _cachedRaw = raw;

    _phaseTimeline = (raw['phase_timeline'] as List? ?? []).map((p) {
      final m = p as Map<String, dynamic>;
      return PhaseSegment(
        phase:     m['phase']      as String,
        startTime: (m['start_time'] as num).toDouble(),
        endTime:   (m['end_time']   as num).toDouble(),
      );
    }).toList();

    _toolsDetected = (raw['tools_detected'] as List? ?? []).map((t) {
      final m = t as Map<String, dynamic>;
      return ToolResult(
        tool:           m['tool']            as String,
        framesDetected: (m['frames_detected'] as num).toInt(),
      );
    }).toList();

    notifyListeners();
  }

  void clear() {
    _result        = null;
    // _cachedRaw intentionally NOT cleared — Analyze button needs it
    _phaseTimeline = [];
    _toolsDetected = [];
    notifyListeners();
  }

  // ── Derived helpers used by Analysis tab widgets ──────────────────────────

  /// Duration of each phase in seconds.
  Map<String, double> get phaseDurations {
    final map = <String, double>{};
    for (final s in _phaseTimeline) {
      map[s.phase] = (map[s.phase] ?? 0) + s.duration;
    }
    return map;
  }

  /// Percentage of total video time each phase occupies.
  Map<String, double> get phasePercentages {
    if (totalDuration <= 0) return {};
    return {
      for (final e in phaseDurations.entries)
        e.key: (e.value / totalDuration) * 100,
    };
  }

  /// Total frames detected per tool (already in toolsDetected).
  /// Returns sorted descending by frame count.
  List<ToolResult> get toolsSorted =>
      [..._toolsDetected]..sort((a, b) => b.framesDetected - a.framesDetected);

  /// Which tools were active during each phase window.
  /// Key = phase name, Value = set of tool names detected in that time window.
  ///
  /// Logic: a tool is "present" in a phase if the tool's frame count is > 0
  /// AND the phase segment overlaps with any other phase that tool appeared in.
  /// Since the backend only gives total frame counts (not per-frame presence),
  /// we use a proportional heuristic: assign tools to phases based on
  /// phase duration weight × tool count.
  Map<String, Set<String>> get phaseToolMap {
    final map = <String, Set<String>>{};
    for (final seg in _phaseTimeline) {
      map[seg.phase] ??= {};
    }
    // Distribute each tool proportionally across all phases by duration.
    // A tool is considered present in a phase if its expected frame count
    // in that phase is >= 1.
    final samplesPerSec = fps / 2; // inference samples at ~2fps
    for (final tool in _toolsDetected) {
      for (final seg in _phaseTimeline) {
        final expectedFrames = seg.duration * samplesPerSec *
            (tool.framesDetected / (totalDuration * samplesPerSec).clamp(1, double.infinity));
        if (expectedFrames >= 1.0) {
          map[seg.phase]!.add(tool.tool);
        }
      }
    }
    return map;
  }

  /// Number of phase transitions (phase changes) in the timeline.
  int get transitionCount => (_phaseTimeline.length - 1).clamp(0, 9999);

  /// Longest single phase segment.
  PhaseSegment? get longestPhase => _phaseTimeline.isEmpty
      ? null
      : _phaseTimeline.reduce((a, b) => a.duration > b.duration ? a : b);

  /// Shortest single phase segment.
  PhaseSegment? get shortestPhase => _phaseTimeline.isEmpty
      ? null
      : _phaseTimeline.reduce((a, b) => a.duration < b.duration ? a : b);

  /// How many distinct tools were used.
  int get toolDiversityScore => _toolsDetected.length;

  /// Dominant phase (longest cumulative duration).
  String get dominantPhase {
    if (_phaseTimeline.isEmpty) return '—';
    final d = phaseDurations;
    return d.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Most used tool (highest frame count).
  String get dominantTool {
    if (_toolsDetected.isEmpty) return '—';
    return toolsSorted.first.tool;
  }
}

// ── Sub-models ────────────────────────────────────────────────────────────────

class PhaseSegment {
  final String phase;
  final double startTime;
  final double endTime;

  const PhaseSegment({
    required this.phase,
    required this.startTime,
    required this.endTime,
  });

  double get duration => (endTime - startTime).clamp(0.0, double.infinity);
}

class ToolResult {
  final String tool;
  final int    framesDetected;

  const ToolResult({required this.tool, required this.framesDetected});
}