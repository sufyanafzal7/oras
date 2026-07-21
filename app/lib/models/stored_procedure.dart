import 'dart:convert';

/// One record per analyzed video, persisted in SharedPreferences.
/// [rawResult] is the full JSON map returned by the Flask backend.
class StoredProcedure {
  final String              id;
  final String              fileName;
  final double              durationSeconds;
  final DateTime            processedAt;
  final int                 phaseCount;
  final int                 toolCount;
  final String              dominantPhase;
  final String              dominantTool;
  final Map<String, dynamic> rawResult;

  const StoredProcedure({
    required this.id,
    required this.fileName,
    required this.durationSeconds,
    required this.processedAt,
    required this.phaseCount,
    required this.toolCount,
    required this.dominantPhase,
    required this.dominantTool,
    required this.rawResult,
  });

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':              id,
    'fileName':        fileName,
    'durationSeconds': durationSeconds,
    'processedAt':     processedAt.toIso8601String(),
    'phaseCount':      phaseCount,
    'toolCount':       toolCount,
    'dominantPhase':   dominantPhase,
    'dominantTool':    dominantTool,
    'rawResult':       rawResult,
  };

  factory StoredProcedure.fromJson(Map<String, dynamic> j) => StoredProcedure(
    id:              j['id']              as String,
    fileName:        j['fileName']        as String,
    durationSeconds: (j['durationSeconds'] as num).toDouble(),
    processedAt:     DateTime.parse(j['processedAt'] as String),
    phaseCount:      j['phaseCount']      as int,
    toolCount:       j['toolCount']       as int,
    dominantPhase:   j['dominantPhase']   as String,
    dominantTool:    j['dominantTool']    as String,
    rawResult:       Map<String, dynamic>.from(j['rawResult'] as Map),
  );

  // ── Factory from raw backend result ───────────────────────────────────────

  factory StoredProcedure.fromRaw({
    required String              fileName,
    required Map<String, dynamic> raw,
  }) {
    final phases     = (raw['phase_timeline'] as List? ?? []);
    final tools      = (raw['tools_detected'] as List? ?? []);
    final duration   = (raw['duration']       as num?)?.toDouble() ?? 0.0;

    // Dominant phase — most cumulative seconds
    final phaseDur   = <String, double>{};
    for (final p in phases) {
      final m     = p as Map<String, dynamic>;
      final name  = m['phase']      as String;
      final start = (m['start_time'] as num).toDouble();
      final end   = (m['end_time']   as num).toDouble();
      phaseDur[name] = (phaseDur[name] ?? 0) + (end - start).clamp(0.0, double.infinity);
    }
    final domPhase = phaseDur.isEmpty
        ? '—'
        : phaseDur.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // Dominant tool — highest frame count
    final domTool = tools.isEmpty
        ? '—'
        : (tools.map((t) => t as Map<String, dynamic>).reduce(
          (a, b) => (a['frames_detected'] as int) >= (b['frames_detected'] as int) ? a : b,
    )['tool'] as String);

    return StoredProcedure(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      fileName:        fileName,
      durationSeconds: duration,
      processedAt:     DateTime.now(),
      phaseCount:      phases.length,
      toolCount:       tools.length,
      dominantPhase:   domPhase,
      dominantTool:    domTool,
      rawResult:       raw,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get formattedDate {
    final d = processedAt;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  /// Encodes the entire object to a JSON string for SharedPreferences storage.
  String encode() => jsonEncode(toJson());

  static StoredProcedure decode(String s) =>
      StoredProcedure.fromJson(jsonDecode(s) as Map<String, dynamic>);
}