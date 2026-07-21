import 'package:flutter/material.dart';

enum ProcedureStatus { completed, analyzing, failed }

// ── Sub-models ───────────────────────────────────────────────────────────────

class PhaseEntry {
  final String phase;
  final double startTime; // seconds
  final double endTime;   // seconds

  const PhaseEntry({
    required this.phase,
    required this.startTime,
    required this.endTime,
  });

  factory PhaseEntry.fromJson(Map<String, dynamic> j) => PhaseEntry(
    phase:     j['phase']      as String,
    startTime: (j['start_time'] as num).toDouble(),
    endTime:   (j['end_time']   as num).toDouble(),
  );
}

class ToolEntry {
  final String tool;
  final int framesDetected;

  const ToolEntry({required this.tool, required this.framesDetected});

  factory ToolEntry.fromJson(Map<String, dynamic> j) => ToolEntry(
    tool:           j['tool']             as String,
    framesDetected: j['frames_detected']  as int,
  );
}

// ── Main model ────────────────────────────────────────────────────────────────

class Procedure {
  final String id;
  final String title;
  final String surgeonName;
  final DateTime date;
  final ProcedureStatus status;

  // Populated after backend analysis completes
  final Duration? duration;
  final List<PhaseEntry> phaseTimeline;
  final List<ToolEntry>  toolsDetected;

  const Procedure({
    required this.id,
    required this.title,
    required this.surgeonName,
    required this.date,
    required this.status,
    this.duration,
    this.phaseTimeline = const [],
    this.toolsDetected = const [],
  });
}