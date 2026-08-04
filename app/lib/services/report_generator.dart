import 'dart:typed_data';
import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/stored_procedure.dart';
import '../theme/app_constants.dart';

/// Builds a full-colour PDF report from a [StoredProcedure].
///
/// The PDF mirrors what the app shows:
///   Page 1 — Cover: procedure name, date, key stats
///   Page 2 — Upload Tab data: duration, tools detected/absent, phase summary,
///             tool scrubber (horizontal bar per tool), phase scrubber (Gantt),
///             phase distribution %
///   Page 3 — Analysis Tab data: all 9 sections as text/chart primitives
///
/// Every page uses PageTheme.buildBackground so the black background fills
/// the ENTIRE page — including margins — not just the content area.
class ReportGenerator {
  // ── Colour palette matching AppColors ────────────────────────────────────
  static const _bg         = PdfColor.fromInt(0xFF0A0D12);
  static const _surface    = PdfColor.fromInt(0xFF12161F);
  static const _border     = PdfColor.fromInt(0xFF222936);
  static const _textPri    = PdfColor.fromInt(0xFFE7ECF2);
  static const _textSec    = PdfColor.fromInt(0xFF8A94A6);
  static const _textMuted  = PdfColor.fromInt(0xFF565F70);
  static const _cyan       = PdfColor.fromInt(0xFF4FD1E8);
  static const _green      = PdfColor.fromInt(0xFF3DDC97);
  static const _amber      = PdfColor.fromInt(0xFFE8A33D);

  static PdfColor _phaseColor(String phase) {
    final c = kPhaseColors[phase];
    if (c == null) return _textSec;
    return PdfColor.fromInt(c.value);
  }

  static const _toolColorMap = {
    'grasper':     PdfColor.fromInt(0xFF4FC3F7),
    'bipolar':     PdfColor.fromInt(0xFFE8447A),
    'hook':        PdfColor.fromInt(0xFF81C784),
    'scissors':    PdfColor.fromInt(0xFFBA68C8),
    'clipper':     PdfColor.fromInt(0xFFFFB74D),
    'irrigator':   PdfColor.fromInt(0xFF4DB6AC),
    'specimenbag': PdfColor.fromInt(0xFFFFD54F),
  };

  static PdfColor _toolColor(String tool) =>
      _toolColorMap[tool] ?? _textSec;

  // ── Public API ────────────────────────────────────────────────────────────

  static Future<Uint8List> generate(StoredProcedure proc) async {
    final pdf  = pw.Document();
    final raw  = proc.rawResult;
    final phases = (raw['phase_timeline'] as List? ?? [])
        .map((p) => p as Map<String, dynamic>)
        .toList();
    final tools  = (raw['tools_detected'] as List? ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
    final duration = proc.durationSeconds;

    final phaseDur = <String, double>{};
    for (final p in phases) {
      final name  = p['phase'] as String;
      final start = (p['start_time'] as num).toDouble();
      final end   = (p['end_time']   as num).toDouble();
      phaseDur[name] = (phaseDur[name] ?? 0) + (end - start).clamp(0, double.infinity);
    }
    final totalPhaseSec = phaseDur.values.fold(0.0, (a, b) => a + b);

    final toolFrames = <String, int>{};
    for (final t in tools) {
      toolFrames[t['tool'] as String] = (t['frames_detected'] as num).toInt();
    }
    final maxFrames = toolFrames.isEmpty
        ? 1
        : toolFrames.values.reduce((a, b) => a > b ? a : b);

    pdf.addPage(_coverPage(proc));

    pdf.addPage(_uploadDataPage(
      proc: proc, phases: phases, tools: tools, phaseDur: phaseDur,
      totalPhaseSec: totalPhaseSec, toolFrames: toolFrames,
      maxFrames: maxFrames, duration: duration,
    ));

    pdf.addPage(_analysisDataPage(
      proc: proc, phases: phases, tools: tools, phaseDur: phaseDur,
      totalPhaseSec: totalPhaseSec, toolFrames: toolFrames,
      maxFrames: maxFrames, duration: duration,
    ));

    return pdf.save();
  }

  static Future<Uint8List> generateToolsTimeline(StoredProcedure proc) async {
    final pdf  = pw.Document();
    final raw  = proc.rawResult;
    final tools  = (raw['tools_detected'] as List? ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
    final duration = proc.durationSeconds;
    final toolFrames = <String, int>{};
    for (final t in tools) {
      toolFrames[t['tool'] as String] = (t['frames_detected'] as num).toInt();
    }
    final maxFrames = toolFrames.isEmpty ? 1
        : toolFrames.values.reduce((a, b) => a > b ? a : b);

    pdf.addPage(_darkPage(build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('TOOLS TIMELINE', 'Instrument activity across procedure duration', proc.fileName),
        pw.SizedBox(height: 16),
        _toolScrubber(toolFrames, maxFrames, duration),
      ],
    )));
    return pdf.save();
  }

  static Future<Uint8List> generatePhaseTimeline(StoredProcedure proc) async {
    final pdf  = pw.Document();
    final raw  = proc.rawResult;
    final phases = (raw['phase_timeline'] as List? ?? [])
        .map((p) => p as Map<String, dynamic>)
        .toList();
    final duration = proc.durationSeconds;

    pdf.addPage(_darkPage(build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeader('PHASE TIMELINE', 'Surgical phase progression across procedure', proc.fileName),
        pw.SizedBox(height: 16),
        _ganttTimeline(phases, duration),
      ],
    )));
    return pdf.save();
  }

  static Future<Uint8List> generateAnalysisOnly(StoredProcedure proc) async {
    final pdf  = pw.Document();
    final raw  = proc.rawResult;
    final phases = (raw['phase_timeline'] as List? ?? [])
        .map((p) => p as Map<String, dynamic>)
        .toList();
    final tools  = (raw['tools_detected'] as List? ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
    final duration = proc.durationSeconds;
    final phaseDur = <String, double>{};
    for (final p in phases) {
      final name  = p['phase'] as String;
      final start = (p['start_time'] as num).toDouble();
      final end   = (p['end_time']   as num).toDouble();
      phaseDur[name] = (phaseDur[name] ?? 0) + (end - start).clamp(0, double.infinity);
    }
    final totalPhaseSec = phaseDur.values.fold(0.0, (a, b) => a + b);
    final toolFrames = <String, int>{};
    for (final t in tools) {
      toolFrames[t['tool'] as String] = (t['frames_detected'] as num).toInt();
    }
    final maxFrames = toolFrames.isEmpty ? 1
        : toolFrames.values.reduce((a, b) => a > b ? a : b);

    pdf.addPage(_analysisDataPage(
      proc: proc, phases: phases, tools: tools, phaseDur: phaseDur,
      totalPhaseSec: totalPhaseSec, toolFrames: toolFrames,
      maxFrames: maxFrames, duration: duration,
    ));
    return pdf.save();
  }

  static Future<Uint8List> generateUploadData(StoredProcedure proc) async {
    final pdf  = pw.Document();
    final raw  = proc.rawResult;
    final phases = (raw['phase_timeline'] as List? ?? [])
        .map((p) => p as Map<String, dynamic>)
        .toList();
    final tools  = (raw['tools_detected'] as List? ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
    final duration = proc.durationSeconds;
    final phaseDur = <String, double>{};
    for (final p in phases) {
      final name  = p['phase'] as String;
      final start = (p['start_time'] as num).toDouble();
      final end   = (p['end_time']   as num).toDouble();
      phaseDur[name] = (phaseDur[name] ?? 0) + (end - start).clamp(0, double.infinity);
    }
    final totalPhaseSec = phaseDur.values.fold(0.0, (a, b) => a + b);
    final toolFrames = <String, int>{};
    for (final t in tools) {
      toolFrames[t['tool'] as String] = (t['frames_detected'] as num).toInt();
    }
    final maxFrames = toolFrames.isEmpty ? 1
        : toolFrames.values.reduce((a, b) => a > b ? a : b);

    pdf.addPage(_uploadDataPage(
      proc: proc, phases: phases, tools: tools, phaseDur: phaseDur,
      totalPhaseSec: totalPhaseSec, toolFrames: toolFrames,
      maxFrames: maxFrames, duration: duration,
    ));
    return pdf.save();
  }

  // ── Page shell — true full-bleed dark background ─────────────────────────

  /// Every page in this report goes through here. PageTheme.buildBackground
  /// paints the background BEHIND the margins too, so the whole sheet is
  /// black edge-to-edge — a plain Container(color:) inside build() only
  /// colors the content area, leaving a white margin border around it.
  static pw.Page _darkPage({required pw.Widget Function(pw.Context) build}) {
    return pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: _theme(),
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: _bg),
        ),
      ),
      build: build,
    );
  }

  // ── Page builders ─────────────────────────────────────────────────────────

  static pw.Page _coverPage(StoredProcedure proc) {
    return _darkPage(build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 4, color: _cyan),
        pw.SizedBox(height: 32),
        pw.Row(children: [
          pw.Container(
            width: 36, height: 36,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0D2A30),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text('O', style: pw.TextStyle(
              color: _cyan, fontSize: 18, fontWeight: pw.FontWeight.bold,
            )),
          ),
          pw.SizedBox(width: 10),
          pw.Text('ORAS', style: pw.TextStyle(
            color: _textPri, fontSize: 18,
            fontWeight: pw.FontWeight.bold, letterSpacing: 2,
          )),
        ]),
        pw.SizedBox(height: 48),
        pw.Text('POST-OPERATIVE', style: pw.TextStyle(
          color: _textMuted, fontSize: 11, letterSpacing: 2,
        )),
        pw.SizedBox(height: 4),
        pw.Text('Clinical Report', style: pw.TextStyle(
          color: _textPri, fontSize: 30, fontWeight: pw.FontWeight.bold,
        )),
        pw.SizedBox(height: 6),
        pw.Text('Operative Recognition & Analysis System',
            style: pw.TextStyle(color: _textSec, fontSize: 13)),
        pw.SizedBox(height: 32),
        pw.Divider(color: _border, thickness: 1),
        pw.SizedBox(height: 24),
        _infoRow('Procedure File',  proc.fileName),
        pw.SizedBox(height: 10),
        _infoRow('Analyzed On',     proc.formattedDate),
        pw.SizedBox(height: 10),
        _infoRow('Duration',        proc.formattedDuration),
        pw.SizedBox(height: 10),
        _infoRow('Phases Detected', '${proc.phaseCount}'),
        pw.SizedBox(height: 10),
        _infoRow('Instruments',     '${proc.toolCount} detected'),
        pw.SizedBox(height: 10),
        _infoRow('Dominant Phase',  proc.dominantPhase),
        pw.SizedBox(height: 10),
        _infoRow('Top Instrument',  proc.dominantTool),
        pw.SizedBox(height: 40),
        pw.Divider(color: _border, thickness: 1),
        pw.SizedBox(height: 12),
        pw.Text(
          'This report was automatically generated by ORAS and is intended '
              'as a clinical documentation aid. It does not constitute a medical '
              'diagnosis or surgical recommendation.',
          style: pw.TextStyle(color: _textMuted, fontSize: 8, lineSpacing: 3),
        ),
      ],
    ));
  }

  static pw.Page _uploadDataPage({
    required StoredProcedure proc,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> tools,
    required Map<String, double> phaseDur,
    required double totalPhaseSec,
    required Map<String, int> toolFrames,
    required int maxFrames,
    required double duration,
  }) {
    final detectedTools = toolFrames.keys.toSet();
    final absentTools   = kAllTools.where((t) => !detectedTools.contains(t)).toList();

    return _darkPage(build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('UPLOAD TAB DATA', proc.fileName),
        pw.SizedBox(height: 16),

        _infoStrip(proc),
        pw.SizedBox(height: 18),

        _label('INSTRUMENTS DETECTED'),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 6, runSpacing: 4,
          children: detectedTools.map((t) => _toolChip(t, true)).toList(),
        ),
        pw.SizedBox(height: 8),
        _label('INSTRUMENTS ABSENT'),
        pw.SizedBox(height: 6),
        pw.Wrap(
          spacing: 6, runSpacing: 4,
          children: absentTools.map((t) => _toolChip(t, false)).toList(),
        ),
        pw.SizedBox(height: 18),

        _label('TOOL ACTIVITY TIMELINE'),
        pw.SizedBox(height: 8),
        _toolScrubber(toolFrames, maxFrames, duration),
        pw.SizedBox(height: 18),

        _label('PHASE TIMELINE (GANTT)'),
        pw.SizedBox(height: 8),
        _ganttTimeline(phases, duration),
        pw.SizedBox(height: 18),

        _label('PHASE DISTRIBUTION'),
        pw.SizedBox(height: 8),
        _phaseDistribution(phaseDur, totalPhaseSec),
      ],
    ));
  }

  static pw.Page _analysisDataPage({
    required StoredProcedure proc,
    required List<Map<String, dynamic>> phases,
    required List<Map<String, dynamic>> tools,
    required Map<String, double> phaseDur,
    required double totalPhaseSec,
    required Map<String, int> toolFrames,
    required int maxFrames,
    required double duration,
  }) {
    final fps         = (proc.rawResult['fps'] as num?)?.toDouble() ?? 25.0;
    final sampPerSec  = fps / 2;
    final totalSamp   = (duration * sampPerSec).clamp(1.0, double.infinity);
    final coMap       = <String, Set<String>>{};
    for (final seg in phases) {
      coMap[seg['phase'] as String] ??= {};
    }
    for (final tEntry in toolFrames.entries) {
      for (final seg in phases) {
        final segDur = ((seg['end_time'] as num).toDouble() -
            (seg['start_time'] as num).toDouble()).clamp(0.0, double.infinity);
        final expected = segDur * sampPerSec * (tEntry.value / totalSamp);
        if (expected >= 1.0) {
          coMap[seg['phase'] as String]!.add(tEntry.key);
        }
      }
    }

    final transitions = (phases.length - 1).clamp(0, 9999);
    final avgPhaseDur = phaseDur.isEmpty
        ? 0.0
        : phaseDur.values.fold(0.0, (a, b) => a + b) / phaseDur.length;
    double balanceScore = 0.0;
    if (phaseDur.isNotEmpty && totalPhaseSec > 0) {
      final ideal  = totalPhaseSec / phaseDur.length;
      final sumDev = phaseDur.values.fold<double>(
          0, (s, d) => s + (d - ideal).abs());
      balanceScore = ((1.0 - (sumDev / (totalPhaseSec * phaseDur.length))) * 100)
          .clamp(0.0, 100.0);
    }
    final diversity    = toolFrames.length;
    final divPct       = (diversity / kAllTools.length) * 100;
    final complexityPM = duration > 0
        ? (transitions / (duration / 60)).toStringAsFixed(1)
        : '0.0';

    return _darkPage(build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pageHeader('ANALYSIS TAB DATA', proc.fileName),
        pw.SizedBox(height: 14),

        _label('PROCEDURE SUMMARY'),
        pw.SizedBox(height: 6),
        _summaryStrip(proc, phases, toolFrames),
        pw.SizedBox(height: 14),

        _label('INSTRUMENT USAGE (frames detected)'),
        pw.SizedBox(height: 6),
        _toolBarChart(toolFrames, maxFrames),
        pw.SizedBox(height: 14),

        _label('PHASE BREAKDOWN'),
        pw.SizedBox(height: 6),
        _phaseBreakdownTable(phaseDur, totalPhaseSec, coMap),
        pw.SizedBox(height: 14),

        _label('PHASE-INSTRUMENT MATRIX'),
        pw.SizedBox(height: 6),
        _coMatrix(phaseDur.keys.toList(), coMap),
        pw.SizedBox(height: 14),

        _label('WORKFLOW EFFICIENCY METRICS'),
        pw.SizedBox(height: 6),
        _efficiencyTable(
          transitions:   transitions,
          avgPhaseDur:   avgPhaseDur,
          balanceScore:  balanceScore,
          diversity:     diversity,
          divPct:        divPct,
          complexityPM:  complexityPM,
          phaseDur:      phaseDur,
          duration:      duration,
        ),
      ],
    ));
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  static pw.Widget _infoStrip(StoredProcedure proc) {
    return pw.Row(children: [
      pw.Expanded(child: _statBox('DURATION',   proc.formattedDuration, _cyan)),
      pw.SizedBox(width: 8),
      pw.Expanded(child: _statBox('PHASES',     '${proc.phaseCount}',   _cyan)),
      pw.SizedBox(width: 8),
      pw.Expanded(child: _statBox('INSTRUMENTS','${proc.toolCount}',    _green)),
      pw.SizedBox(width: 8),
      pw.Expanded(child: _statBox('TOP PHASE',  _shortPhase(proc.dominantPhase), _amber)),
    ]);
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(color: _textMuted, fontSize: 7, letterSpacing: 0.8)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(color: color, fontSize: 14, fontWeight: pw.FontWeight.bold),
              maxLines: 1),
        ],
      ),
    );
  }

  static pw.Widget _toolScrubber(
      Map<String, int> toolFrames, int maxFrames, double duration) {
    return pw.Column(
      children: kAllTools.map((tool) {
        final frames   = toolFrames[tool] ?? 0;
        final frac     = maxFrames > 0 ? frames / maxFrames : 0.0;
        final color    = _toolColor(tool);
        final active   = frames > 0;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 72,
              child: pw.Text(tool,
                style: pw.TextStyle(
                  color: active ? _textPri : _textMuted,
                  fontSize: 9,
                  fontWeight: active ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.LayoutBuilder(builder: (ctx, constraints) {
                final w = constraints!.maxWidth;
                return pw.Stack(children: [
                  pw.Container(
                    height: 10,
                    width: w,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF000000),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                  ),
                  pw.Container(
                    height: 10,
                    width: w * frac.clamp(0.0, 1.0),
                    decoration: pw.BoxDecoration(
                      color: active
                          ? PdfColor(color.red, color.green, color.blue, 0.8)
                          : _border,
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                  ),
                ]);
              }),
            ),
            pw.SizedBox(width: 6),
            pw.SizedBox(
              width: 36,
              child: pw.Text(
                active ? '${(frac * 100).toStringAsFixed(1)}%' : '-',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  color: active ? color : _textMuted,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  static pw.Widget _ganttTimeline(
      List<Map<String, dynamic>> phases, double duration) {
    if (phases.isEmpty || duration <= 0) return pw.SizedBox(height: 0);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.LayoutBuilder(builder: (ctx, constraints) {
          final w = constraints!.maxWidth;
          return pw.Stack(children: [
            pw.Container(
              height: 24,
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF000000),
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
            ...phases.map((seg) {
              final start = (seg['start_time'] as num).toDouble();
              final end   = (seg['end_time']   as num).toDouble();
              final phase = seg['phase'] as String;
              final x1    = (start / duration) * w;
              final segW  = ((end - start) / duration * w).clamp(2.0, double.infinity);
              final col   = _phaseColor(phase);
              return pw.Positioned(
                left: x1,
                top: 0, bottom: 0,
                child: pw.Container(
                  width: segW,
                  margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(col.red, col.green, col.blue, 0.8),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ]);
        }),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('0:00',               style: pw.TextStyle(color: _textMuted, fontSize: 7)),
            pw.Text(_fmt(duration / 2),   style: pw.TextStyle(color: _textMuted, fontSize: 7)),
            pw.Text(_fmt(duration),       style: pw.TextStyle(color: _textMuted, fontSize: 7)),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 8, runSpacing: 4,
          children: _uniquePhases(phases).map((phase) {
            final col = _phaseColor(phase);
            return pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              pw.Container(
                width: 7, height: 7,
                decoration: pw.BoxDecoration(
                  color: col, borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(phase, style: pw.TextStyle(color: _textSec, fontSize: 7)),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _phaseDistribution(
      Map<String, double> phaseDur, double total) {
    if (phaseDur.isEmpty || total <= 0) return pw.SizedBox(height: 0);
    final sorted = phaseDur.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return pw.Column(
      children: sorted.map((e) {
        final col  = _phaseColor(e.key);
        final frac = total > 0 ? e.value / total : 0.0;
        final mm   = (e.value ~/ 60).toString().padLeft(2, '0');
        final ss   = (e.value.toInt() % 60).toString().padLeft(2, '0');
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Container(
                  width: 6, height: 6,
                  decoration: pw.BoxDecoration(color: col, shape: pw.BoxShape.circle),
                ),
                pw.SizedBox(width: 5),
                pw.Expanded(
                  child: pw.Text(e.key,
                      style: pw.TextStyle(color: _textSec, fontSize: 8)),
                ),
                pw.Text('$mm:$ss  ${(frac * 100).toStringAsFixed(1)}%',
                    style: pw.TextStyle(color: col, fontSize: 8)),
              ]),
              pw.SizedBox(height: 3),
              pw.LayoutBuilder(builder: (ctx, constraints) {
                final w = constraints!.maxWidth;
                return pw.Stack(children: [
                  pw.Container(
                    height: 4,
                    width: w,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF000000),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                  ),
                  pw.Container(
                    height: 4,
                    width: w * frac.clamp(0.0, 1.0),
                    decoration: pw.BoxDecoration(
                      color: PdfColor(col.red, col.green, col.blue, 0.85),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                  ),
                ]);
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _summaryStrip(
      StoredProcedure proc,
      List<Map<String, dynamic>> phases,
      Map<String, int> toolFrames) {
    final transitions = (phases.length - 1).clamp(0, 9999);
    final items = [
      ('DURATION',     proc.formattedDuration,      'min:sec',   _cyan),
      ('PHASES',       '${phases.length}',           'detected',  _cyan),
      ('TRANSITIONS',  '$transitions',               'changes',   _amber),
      ('INSTRUMENTS',  '${toolFrames.length}',       'active',    _cyan),
      ('DOM. PHASE',   _shortPhase(proc.dominantPhase), 'longest', _green),
      ('TOP TOOL',     proc.dominantTool,            'most used', _green),
    ];
    return pw.Row(children: items.expand((item) => [
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(right: 4),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _border),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(item.$1, style: pw.TextStyle(color: _textMuted, fontSize: 6, letterSpacing: 0.5)),
            pw.SizedBox(height: 3),
            pw.Text(item.$2,
              style: pw.TextStyle(color: item.$4, fontSize: 11, fontWeight: pw.FontWeight.bold),
              maxLines: 1,
            ),
            pw.Text(item.$3, style: pw.TextStyle(color: _textMuted, fontSize: 6)),
          ],
        ),
      )),
    ]).toList());
  }

  static pw.Widget _toolBarChart(Map<String, int> toolFrames, int maxFrames) {
    return pw.Column(
      children: kAllTools.map((tool) {
        final frames = toolFrames[tool] ?? 0;
        final frac   = maxFrames > 0 ? frames / maxFrames : 0.0;
        final color  = _toolColor(tool);
        final active = frames > 0;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(children: [
            pw.SizedBox(
              width: 72,
              child: pw.Text(tool,
                style: pw.TextStyle(
                  color: active ? _textPri : _textMuted, fontSize: 8,
                  fontWeight: active ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.LayoutBuilder(builder: (ctx, constraints) {
                final w = constraints!.maxWidth;
                return pw.Stack(children: [
                  pw.Container(
                    height: 14,
                    width: w,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF000000),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                  ),
                  if (active)
                    pw.Container(
                      height: 14,
                      width: w * frac.clamp(0.0, 1.0),
                      decoration: pw.BoxDecoration(
                        color: PdfColor(color.red, color.green, color.blue, 0.8),
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                    ),
                ]);
              }),
            ),
            pw.SizedBox(width: 6),
            pw.SizedBox(
              width: 36,
              child: pw.Text(
                active ? '$frames' : '-',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  color: active ? color : _textMuted, fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }

  static pw.Widget _phaseBreakdownTable(
      Map<String, double> phaseDur,
      double total,
      Map<String, Set<String>> coMap) {
    if (phaseDur.isEmpty) return pw.SizedBox(height: 0);
    final sorted = phaseDur.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rows = sorted.map((e) {
      final col   = _phaseColor(e.key);
      final frac  = total > 0 ? e.value / total : 0.0;
      final mm    = (e.value ~/ 60).toString().padLeft(2, '0');
      final ss    = (e.value.toInt() % 60).toString().padLeft(2, '0');
      final tools = (coMap[e.key] ?? <String>{}).join(', ');
      return pw.TableRow(children: [
        _cell(e.key, color: col, bold: true),
        _cell('$mm:$ss'),
        _cell('${(frac * 100).toStringAsFixed(1)}%', color: col),
        _cell(tools.isEmpty ? '-' : tools),
      ]);
    }).toList();

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.5),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _surface),
          children: [
            _headerCell('PHASE'),
            _headerCell('DURATION'),
            _headerCell('SHARE'),
            _headerCell('INSTRUMENTS'),
          ],
        ),
        ...rows,
      ],
    );
  }

  static pw.Widget _coMatrix(
      List<String> phases, Map<String, Set<String>> coMap) {
    if (phases.isEmpty) return pw.SizedBox(height: 0);
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        for (int i = 0; i < kAllTools.length; i++)
          (i + 1): const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _surface),
          children: [
            _headerCell('PHASE'),
            ...kAllTools.map((t) => _headerCell(t.substring(0, 4).toUpperCase())),
          ],
        ),
        ...phases.map((phase) {
          final col   = _phaseColor(phase);
          final tools = coMap[phase] ?? {};
          return pw.TableRow(children: [
            _cell(_shortPhase(phase), color: col, bold: true),
            ...kAllTools.map((tool) {
              final present = tools.contains(tool);
              return pw.Container(
                color: present
                    ? PdfColor(col.red, col.green, col.blue, 0.25)
                    : PdfColor.fromInt(0xFF000000),
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.center,
                child: pw.Text(present ? 'Y' : '.',
                  style: pw.TextStyle(
                    color: present ? col : _textMuted,
                    fontSize: 8,
                    fontWeight: present ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              );
            }),
          ]);
        }),
      ],
    );
  }

  static pw.Widget _efficiencyTable({
    required int    transitions,
    required double avgPhaseDur,
    required double balanceScore,
    required int    diversity,
    required double divPct,
    required String complexityPM,
    required Map<String, double> phaseDur,
    required double duration,
  }) {
    final longest  = phaseDur.isEmpty ? null
        : phaseDur.entries.reduce((a, b) => a.value > b.value ? a : b);
    final shortest = phaseDur.isEmpty ? null
        : phaseDur.entries.reduce((a, b) => a.value < b.value ? a : b);

    final metrics = [
      ('LONGEST PHASE',         longest != null ? '${_fmt(longest.value)} (${_shortPhase(longest.key)})' : '-', _amber),
      ('SHORTEST PHASE',        shortest != null ? '${_fmt(shortest.value)} (${_shortPhase(shortest.key)})' : '-', _amber),
      ('AVG PHASE DURATION',    _fmt(avgPhaseDur), _cyan),
      ('PHASE TRANSITIONS',     '$transitions  ($complexityPM/min)', _amber),
      ('PHASE BALANCE SCORE',   '${balanceScore.toStringAsFixed(1)}%  (${balanceScore > 60 ? "Well balanced" : "Dominated"})', balanceScore > 60 ? _green : _amber),
      ('INSTRUMENT COVERAGE',   '$diversity / ${kAllTools.length}  (${divPct.toStringAsFixed(0)}% of kit)', divPct > 60 ? _green : _cyan),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children: metrics.map((m) => pw.TableRow(children: [
        pw.Container(
          color: _surface,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(m.$1,
              style: pw.TextStyle(color: _textMuted, fontSize: 7, letterSpacing: 0.5)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(m.$2,
              style: pw.TextStyle(color: m.$3, fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ),
      ])).toList(),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  static pw.Widget _pageHeader(String section, String fileName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Container(width: 3, height: 16, color: _cyan),
          pw.SizedBox(width: 8),
          pw.Text('ORAS  ·  $section',
              style: pw.TextStyle(color: _cyan, fontSize: 8, letterSpacing: 1)),
          pw.Spacer(),
          pw.Text(fileName,
              style: pw.TextStyle(color: _textMuted, fontSize: 7),
              maxLines: 1),
        ]),
        pw.Divider(color: _border, thickness: 0.5),
      ],
    );
  }

  static pw.Widget _sectionHeader(
      String title, String subtitle, String fileName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(color: _cyan, fontSize: 14,
                fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(subtitle,
            style: pw.TextStyle(color: _textSec, fontSize: 9)),
        pw.Text(fileName,
            style: pw.TextStyle(color: _textMuted, fontSize: 8)),
        pw.SizedBox(height: 8),
        pw.Divider(color: _border, thickness: 0.5),
      ],
    );
  }

  static pw.Widget _label(String text) => pw.Text(
    text,
    style: pw.TextStyle(color: _textMuted, fontSize: 8, letterSpacing: 1.2),
  );

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(children: [
      pw.SizedBox(
        width: 110,
        child: pw.Text(label,
            style: pw.TextStyle(color: _textMuted, fontSize: 9)),
      ),
      pw.Text(value,
          style: pw.TextStyle(
              color: _textPri, fontSize: 9, fontWeight: pw.FontWeight.bold)),
    ]);
  }

  static pw.Widget _toolChip(String tool, bool active) {
    final color = active ? _toolColor(tool) : _textMuted;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: active
            ? PdfColor(color.red, color.green, color.blue, 0.12)
            : _surface,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(
          color: active
              ? PdfColor(color.red, color.green, color.blue, 0.5)
              : _border,
        ),
      ),
      child: pw.Text(tool,
          style: pw.TextStyle(
              color: color, fontSize: 8,
              fontWeight: active ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _cell(String text, {PdfColor? color, bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          maxLines: 2,
          style: pw.TextStyle(
            color: color ?? _textSec,
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          )),
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(color: _textMuted, fontSize: 7, letterSpacing: 0.5)),
    );
  }

  static pw.ThemeData _theme() {
    return pw.ThemeData(
      defaultTextStyle: pw.TextStyle(color: _textPri, fontSize: 10),
    );
  }

  static List<String> _uniquePhases(List<Map<String, dynamic>> phases) {
    final seen = <String>{};
    return phases
        .map((p) => p['phase'] as String)
        .where(seen.add)
        .toList();
  }

  static String _fmt(double s) {
    final m  = (s ~/ 60).toString().padLeft(2, '0');
    final sc = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sc';
  }

  static String _shortPhase(String p) {
    const map = {
      'CalotTriangleDissection': 'Calot',
      'CleaningCoagulation':     'Cleaning',
      'ClippingCutting':         'Clipping',
      'GallbladderDissection':   'GB Diss.',
      'GallbladderPackaging':    'GB Pack.',
      'GallbladderRetraction':   'GB Retr.',
      'Preparation':             'Prep',
    };
    return map[p] ?? p;
  }
}