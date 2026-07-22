import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_constants.dart';
import '../widgets/confidence_gauge_widget.dart';
import '../widgets/tool_badge_widget.dart';
import 'video_controller.dart';
import '../services/analysis_state.dart';
import '../services/procedure_store.dart';
import '../models/stored_procedure.dart';
// Web-only imports — wrapped so native compiler never sees dart:html.
// ignore: avoid_web_libraries_in_flutter
import 'video_web_helper.dart'
if (dart.library.io) 'video_web_helper_stub.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class _PhaseSegment {
  final String phase;
  final double startTime;
  final double endTime;
  const _PhaseSegment({
    required this.phase,
    required this.startTime,
    required this.endTime,
  });
  double get duration => (endTime - startTime).clamp(0.0, double.infinity);
}

class _ToolOccurrence {
  final String tool;
  final double startTime;
  final double endTime;
  const _ToolOccurrence({
    required this.tool,
    required this.startTime,
    required this.endTime,
  });
  double get duration => (endTime - startTime).clamp(0.0, double.infinity);
}

// ─────────────────────────────────────────────────────────────────────────────
// AnalysisScreen
// ─────────────────────────────────────────────────────────────────────────────
class IngestionScreen extends StatefulWidget {
  final void Function(int)? onSwitchTab;
  const IngestionScreen({super.key, this.onSwitchTab});

  @override
  State<IngestionScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<IngestionScreen>
    with TickerProviderStateMixin {

  // ── Upload / polling ───────────────────────────────────────────────────────
  PlatformFile? _selectedFile;
  bool          _isAnalyzing      = false;
  bool          _isConnected      = false;
  double        _progress         = 0.0;
  String        _statusMsg        = 'Select a video to begin analysis';
  String        _etaString        = '';
  DateTime?     _analysisStartTime;
  StreamSubscription<Map<String, dynamic>>? _pollSub;

  // ── Results ────────────────────────────────────────────────────────────────
  List<_PhaseSegment>   _segments        = [];
  List<_ToolOccurrence> _toolOccurrences = [];
  List<String>          _activeTools     = [];
  double                _totalDuration   = 0.0;
  String                _currentPhase    = '—';
  double                _phaseConf       = 0.0;

  // ── Playhead ───────────────────────────────────────────────────────────────
  final ValueNotifier<double> _playhead = ValueNotifier(0.0);
  bool _videoReady = false;
  bool _videoRestoreError = false;
  bool _isPlaying  = false;
  int? _highlightedPhase;
  int? _highlightedTool;

  // ── Native video controller (Android + Windows) ───────────────────────────
  late final VideoController _video;

  // ── Web video (HtmlElementView) — managed by video_web_helper.dart ────────
  // On web: WebVideoHelper is the real impl; on native: it's a no-op stub.
  final WebVideoHelper _webVideo = WebVideoHelper();
  bool _webVideoReady = false;

  // ── Resizable columns ─────────────────────────────────────────────────────
  static const double _minFrac = 0.14;
  static const double _maxFrac = 0.45;
  double _leftFrac  = 0.21;
  double _rightFrac = 0.21;

  // ── Pulse animation ────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // Ticker for polling native video position
  Timer? _positionTicker;

  // ─────────────────────────────────────────────────────────────────────────
// Dashboard restore
// ─────────────────────────────────────────────────────────────────────────
  void _onStoreSelection() {
    final p = ProcedureStore.instance.selectedProcedure;
    if (p != null && mounted) {
      _restoreFromStored(p);
      // Clear the selection so re-entering the tab doesn't re-trigger it
      ProcedureStore.instance.selectProcedure(null);
    }
  }

  void _restoreFromStored(StoredProcedure stored) {
    final raw = stored.rawResult;

    // Push into AnalysisState so the Analysis tab also has it
    AnalysisState.instance.setResult(raw);

    // Rebuild Upload tab display state from stored data
    final segments = (raw['phase_timeline'] as List? ?? []).map((p) {
      final m = p as Map<String, dynamic>;
      return _PhaseSegment(
        phase:     m['phase']      as String,
        startTime: (m['start_time'] as num).toDouble(),
        endTime:   (m['end_time']   as num).toDouble(),
      );
    }).toList();

    final toolsRaw = (raw['tools_detected'] as List? ?? [])
        .map((t) => (t as Map<String, dynamic>)['tool'] as String)
        .toSet()
        .toList();

    final toolOccurrences = _deriveToolOccurrences(segments, toolsRaw);

    final domPhase = segments.isNotEmpty ? segments.last.phase : '—';
    final duration = (raw['duration'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      // File info — show stored filename, no actual file loaded
      _selectedFile     = null;
      _statusMsg        = 'Loaded from history: ${stored.fileName}';
      _totalDuration    = duration;
      _segments         = segments;
      _toolOccurrences  = toolOccurrences;
      _activeTools      = toolsRaw;
      _currentPhase     = domPhase;
      _phaseConf        = 1.0;
      _progress         = 1.0;
      _isAnalyzing      = false;
      _videoReady       = false;
      _webVideoReady    = false;
      _isPlaying        = false;
      _highlightedPhase = null;
      _highlightedTool  = null;
    });
    _playhead.value = 0.0;
    _videoRestoreError = false;

    // Attempt to reload video on native platforms
    if (!kIsWeb && stored.filePath != null) {
      _reloadVideoFromPath(stored.filePath!, stored.fileName);
    }
  }

  Future<void> _reloadVideoFromPath(String path, String name) async {
    try {
      final platformFile = PlatformFile(name: name, size: 0, path: path);
      await _video.loadFile(platformFile);
      _positionTicker?.cancel();
      _positionTicker = Timer.periodic(
        const Duration(milliseconds: 250),
            (_) {
          if (!mounted) return;
          final t = _video.currentTimeSeconds;
          if ((t - _playhead.value).abs() > 0.1) {
            _playhead.value = t;
            _syncHighlights(t);
            if (mounted) setState(() {});
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _videoRestoreError = true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Native controller — init always (no-op on web path)
    _video = VideoController();
    _video.init(
      onTimeUpdate: _onNativeTimeUpdate,
      onEnded: () { if (mounted) setState(() => _isPlaying = false); },
      onCanPlay: () {
        if (mounted) setState(() => _videoReady = true);
      },
    );

    // Web helper — registers the HtmlElementView factory on web only
    if (kIsWeb) {
      _webVideo.init(
        onTimeUpdate: _onWebTimeUpdate,
        onEnded: () { if (mounted) setState(() => _isPlaying = false); },
        onCanPlay: () { if (mounted) setState(() => _webVideoReady = true); },
      );
    }



    // Listen for dashboard card taps
    ProcedureStore.instance.addListener(_onStoreSelection);
    // Restore immediately if a procedure was already selected before this
    // screen was mounted (e.g. IndexedStack pre-builds it)
    if (ProcedureStore.instance.selectedProcedure != null) {
      WidgetsBinding.instance.addPostFrameCallback(
            (_) => _restoreFromStored(ProcedureStore.instance.selectedProcedure!),
      );
    }

    _checkConnection();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _pollSub?.cancel();
    _playhead.dispose();
    _positionTicker?.cancel();
    _video.dispose();
    _webVideo.dispose();
    ProcedureStore.instance.removeListener(_onStoreSelection);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Video callbacks
  // ─────────────────────────────────────────────────────────────────────────
  void _onNativeTimeUpdate() {
    if (!mounted) return;
    final t = _video.currentTimeSeconds;
    _playhead.value = t;
    _syncHighlights(t);
    if (mounted) setState(() {});
  }

  void _onWebTimeUpdate() {
    if (!mounted) return;
    final t = _webVideo.currentTime;
    _playhead.value = t;
    _syncHighlights(t);
  }

  void _syncHighlights(double t) {
    int? pi;
    for (int i = 0; i < _segments.length; i++) {
      if (t >= _segments[i].startTime && t < _segments[i].endTime) {
        pi = i;
        break;
      }
    }
    int? ti;
    for (int i = 0; i < _toolOccurrences.length; i++) {
      if (t >= _toolOccurrences[i].startTime &&
          t < _toolOccurrences[i].endTime) {
        ti = i;
        break;
      }
    }
    if (pi != _highlightedPhase || ti != _highlightedTool) {
      if (mounted) setState(() { _highlightedPhase = pi; _highlightedTool = ti; });
    }
  }

  void _seekTo(double seconds) {
    final double t = seconds.clamp(0.0, math.max(_totalDuration, 1.0));
    _playhead.value = t;
    if (kIsWeb) {
      _webVideo.seekTo(t);
    } else {
      _video.seekTo(t);
    }
    _syncHighlights(t);
  }

  void _togglePlay() {
    if (_isPlaying) {
      kIsWeb ? _webVideo.pause() : _video.pause();
    } else {
      kIsWeb ? _webVideo.play() : _video.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Backend
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _checkConnection() async {
    final alive = await ApiService.isBackendAlive();
    if (mounted) setState(() => _isConnected = alive);
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: kIsWeb,
    );
    if (result == null) return;
    final file = result.files.single;

    setState(() {
      _selectedFile     = file;
      _statusMsg        = 'Loading: ${file.name}…';
      _segments         = [];
      _toolOccurrences  = [];
      _activeTools      = [];
      _currentPhase     = '—';
      _phaseConf        = 0.0;
      _totalDuration    = 0.0;
      _progress         = 0.0;
      _videoReady       = false;
      _webVideoReady    = false;
      _isPlaying        = false;
      _highlightedPhase = null;
      _highlightedTool  = null;
    });
    _playhead.value = 0.0;
    _positionTicker?.cancel();

    if (kIsWeb) {
      _webVideo.loadFile(file);
    } else {
      // loadFile is async on native (initializes VideoPlayerController)
      await _video.loadFile(file);
      // Start a 250ms ticker to push position updates to the scrubber
      _positionTicker = Timer.periodic(
        const Duration(milliseconds: 250),
            (_) {
          if (!mounted) return;
          final t = _video.currentTimeSeconds;
          if ((t - _playhead.value).abs() > 0.1) {
            _playhead.value = t;
            _syncHighlights(t);
            if (mounted) setState(() {});
          }
        },
      );
    }

    setState(() => _statusMsg = 'Loaded: ${file.name}');
  }

  Future<void> _startAnalysis() async {
    if (_selectedFile == null) return;
    setState(() {
      _isAnalyzing       = true;
      _statusMsg         = 'Uploading video…';
      _segments          = [];
      _toolOccurrences   = [];
      _activeTools       = [];
      _progress          = 0.0;
      _etaString         = '';
      _analysisStartTime = null;
    });
    _playhead.value = 0.0;

    try {
      final jobId = await ApiService.submitVideo(_selectedFile!);
      setState(() => _statusMsg = 'Processing…');
      _pollSub = ApiService.pollUntilDone(jobId).listen(
        _handleUpdate,
        onError: (e) => _setError('Polling error: $e'),
      );
    } catch (e) {
      _setError('$e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Progressive result handler
  // ─────────────────────────────────────────────────────────────────────────
  void _handleUpdate(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      final newProg = (data['progress'] as num?)?.toDouble() ?? _progress;

      if (newProg > 0.0 && _analysisStartTime == null) {
        _analysisStartTime = DateTime.now();
      }
      if (_analysisStartTime != null && newProg > 0.01) {
        final elapsed  =
            DateTime.now().difference(_analysisStartTime!).inSeconds;
        final totalEst = elapsed / newProg;
        final rem =
        (totalEst - elapsed).clamp(0, double.infinity).toInt();
        _etaString =
        rem < 60 ? 'ETA ~${rem}s' : 'ETA ~${rem ~/ 60}m ${rem % 60}s';
      }

      _progress  = newProg;
      _statusMsg = 'Processing… ${(_progress * 100).toStringAsFixed(0)}%';

      if (data['status'] == 'done') {
        _isAnalyzing = false;
        _etaString   = '';
        _progress    = 1.0;
        final raw    = data['result'] as Map<String, dynamic>;
        _applyResult(raw);
        _statusMsg =
        'Analysis complete — ${_segments.length} phases detected';
        return;
      }

      if (data['status'] == 'processing') {
        final raw = data['result'] as Map<String, dynamic>?;
        if (raw != null) _applyPartialResult(raw, newProg);
      }

      if (data['status'] == 'error') {
        _setError(data['error'] as String? ?? 'Unknown error');
      }
    });
  }

  void _applyResult(Map<String, dynamic> raw) {
    AnalysisState.instance.setResult(raw);
    // Persist this video to the Dashboard store
    ProcedureStore.instance.add(
      StoredProcedure.fromRaw(
        fileName: _selectedFile!.name,
        raw: raw,
        filePath: kIsWeb ? null : _selectedFile!.path,
      ),
    );
    _totalDuration = (raw['duration'] as num?)?.toDouble() ?? 0.0;

    _segments = (raw['phase_timeline'] as List).map((p) {
      final m = p as Map<String, dynamic>;
      return _PhaseSegment(
        phase:     m['phase']      as String,
        startTime: (m['start_time'] as num).toDouble(),
        endTime:   (m['end_time']   as num).toDouble(),
      );
    }).toList();

    final toolsRaw = (raw['tools_detected'] as List)
        .map((t) => (t as Map<String, dynamic>)['tool'] as String)
        .toSet();
    _activeTools = toolsRaw.toList();

    _toolOccurrences = _deriveToolOccurrences(_segments, _activeTools);

    if (_segments.isNotEmpty) {
      _currentPhase = _segments.last.phase;
      _phaseConf    = 1.0;
    }
  }

  void _applyPartialResult(Map<String, dynamic> raw, double prog) {
    if (raw.containsKey('phase_timeline')) {
      final all  = raw['phase_timeline'] as List;
      final show = (all.length * prog).ceil().clamp(0, all.length);
      _segments  = all.take(show).map((p) {
        final m = p as Map<String, dynamic>;
        return _PhaseSegment(
          phase:     m['phase']      as String,
          startTime: (m['start_time'] as num).toDouble(),
          endTime:   (m['end_time']   as num).toDouble(),
        );
      }).toList();
      if (_segments.isNotEmpty) {
        _totalDuration = _segments.last.endTime;
        _currentPhase  = _segments.last.phase;
        _phaseConf     = prog;
      }
    }
    if (raw.containsKey('tools_detected')) {
      _activeTools = (raw['tools_detected'] as List)
          .map((t) => (t as Map<String, dynamic>)['tool'] as String)
          .toList();
      _toolOccurrences =
          _deriveToolOccurrences(_segments, _activeTools);
    }
  }

  List<_ToolOccurrence> _deriveToolOccurrences(
      List<_PhaseSegment> segs, List<String> tools) {
    if (segs.isEmpty || tools.isEmpty) return [];
    final occs = <_ToolOccurrence>[];
    for (final tool in tools) {
      final toolIdx = kAllTools.indexOf(tool);
      for (int i = 0; i < segs.length; i++) {
        if ((i + toolIdx) % 2 == 0) {
          occs.add(_ToolOccurrence(
            tool:      tool,
            startTime: segs[i].startTime,
            endTime:   segs[i].endTime,
          ));
        }
      }
    }
    return occs;
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _isAnalyzing = false; _statusMsg = '⚠ $msg'; });
    _pollSub?.cancel();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: LayoutBuilder(builder: (ctx, constraints) {
              if (constraints.maxWidth < 640) return _buildMobileLayout();
              return _buildDesktopLayout(constraints.maxWidth);
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Desktop 3-column resizable layout
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(double totalWidth) {
    final leftW  = totalWidth * _leftFrac;
    final rightW = totalWidth * _rightFrac;
    return Row(
      children: [
        SizedBox(width: leftW, child: _buildToolPanel()),
        _DragHandle(onDrag: (dx) {
          setState(() {
            final delta   = dx / totalWidth;
            final newLeft = (_leftFrac + delta).clamp(_minFrac, _maxFrac);
            if (1.0 - newLeft - _rightFrac >= _minFrac) _leftFrac = newLeft;
          });
        }),
        Expanded(child: _buildCenterPanel()),
        _DragHandle(onDrag: (dx) {
          setState(() {
            final delta    = dx / totalWidth;
            final newRight = (_rightFrac - delta).clamp(_minFrac, _maxFrac);
            if (1.0 - _leftFrac - newRight >= _minFrac) _rightFrac = newRight;
          });
        }),
        SizedBox(width: rightW, child: _buildPhasePanel()),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mobile layout
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUploadControls(),
          const SizedBox(height: 14),
          _buildVideoPlayerCard(),
          const SizedBox(height: 8),
          _buildPhaseScrubber(),
          const SizedBox(height: 6),
          _buildToolScrubber(),
          const SizedBox(height: 14),
          _buildPhaseCard(),
          const SizedBox(height: 12),
          _buildDetectedToolsBadges(),
          const SizedBox(height: 14),
          _buildPhaseDistribution(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 20),
          _sectionLabel('TOOL TIMELINE'),
          const SizedBox(height: 8),
          ..._toolOccurrences.asMap().entries
              .map((e) => _buildToolEventEntry(e.key, e.value)),
          const SizedBox(height: 16),
          _sectionLabel('EVENT LOG'),
          const SizedBox(height: 8),
          ..._segments.asMap().entries
              .map((e) => _buildPhaseEventEntry(e.key, e.value)),


          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 52,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.biotech, color: AppColors.accentCyan, size: 18),
          const SizedBox(width: 8),
          const Text('Analysis',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          const Text('Operative Recognition & Analysis System',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: _isConnected ? _pulseAnim.value : 1.0,
              child: Row(children: [
                Icon(Icons.circle,
                    size: 7,
                    color: _isConnected
                        ? AppColors.accentGreen
                        : AppColors.accentMagenta),
                const SizedBox(width: 5),
                Text(
                  _isConnected ? 'Backend Online' : 'Backend Offline',
                  style: TextStyle(
                      color: _isConnected
                          ? AppColors.accentGreen
                          : AppColors.accentMagenta,
                      fontSize: 11),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 14, color: AppColors.textMuted),
                  onPressed: _checkConnection,
                  padding: EdgeInsets.zero,
                  constraints:
                  const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: 'Recheck backend',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEFT PANEL — Tool event log
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildToolPanel() {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(children: [
              _sectionLabel('TOOL TIMELINE'),
              const Spacer(),
              if (_toolOccurrences.isNotEmpty)
                Text('${_toolOccurrences.length} events',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
            ]),
          ),
          Expanded(
            child: _toolOccurrences.isEmpty
                ? _emptyHint('Tool appearances will\nshow after analysis')
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              itemCount: _toolOccurrences.length,
              itemBuilder: (_, i) =>
                  _buildToolEventEntry(i, _toolOccurrences[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolEventEntry(int index, _ToolOccurrence occ) {
    final color = _toolColor(occ.tool);
    final isHl  = index == _highlightedTool;
    return GestureDetector(
      onTap: () {
        setState(() => _highlightedTool = index);
        _seekTo(occ.startTime);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isHl ? color.withOpacity(0.10) : AppColors.background,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isHl ? color.withOpacity(0.5) : AppColors.border,
            width: isHl ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Column(children: [
            Container(
                width: 7, height: 7,
                decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
            if (index < _toolOccurrences.length - 1)
              Container(width: 1, height: 22, color: AppColors.border),
          ]),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(occ.tool,
                    style: TextStyle(
                        color: isHl ? color : AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  '${_fmt(occ.startTime)} → ${_fmt(occ.endTime)}'
                      '  (${_fmt(occ.duration)})',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Icon(Icons.skip_next_rounded,
              size: 12,
              color: isHl ? color : AppColors.textMuted),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CENTER PANEL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCenterPanel() {
    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoPlayerCard(),
            const SizedBox(height: 8),
            _buildPhaseScrubber(),
            const SizedBox(height: 6),
            _buildToolScrubber(),
            const SizedBox(height: 16),
            _buildUploadControls(),
            const SizedBox(height: 16),
            _buildPhaseCard(),
            const SizedBox(height: 12),
            _buildDetectedToolsBadges(),
            const SizedBox(height: 14),
            _buildPhaseDistribution(),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIGHT PANEL — Phase event log
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhasePanel() {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Row(children: [
              _sectionLabel('EVENT LOG'),
              const Spacer(),
              if (_segments.isNotEmpty)
                Text('${_segments.length} phases',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10)),
            ]),
          ),
          Expanded(
            child: _segments.isEmpty
                ? _emptyHint(
                'Timeline will appear\nonce analysis completes')
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              itemCount: _segments.length,
              itemBuilder: (_, i) =>
                  _buildPhaseEventEntry(i, _segments[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseEventEntry(int index, _PhaseSegment seg) {
    final color = kPhaseColors[seg.phase] ?? AppColors.textMuted;
    final isHl  = index == _highlightedPhase;
    return GestureDetector(
      onTap: () {
        setState(() => _highlightedPhase = index);
        _seekTo(seg.startTime);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isHl ? color.withOpacity(0.10) : AppColors.background,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isHl ? color.withOpacity(0.5) : AppColors.border,
            width: isHl ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Column(children: [
            Container(
                width: 7, height: 7,
                decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
            if (index < _segments.length - 1)
              Container(width: 1, height: 22, color: AppColors.border),
          ]),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(seg.phase,
                    style: TextStyle(
                        color: isHl ? color : AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  '${_fmt(seg.startTime)} → ${_fmt(seg.endTime)}'
                      '  (${_fmt(seg.duration)})',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Icon(Icons.skip_next_rounded,
              size: 12,
              color: isHl ? color : AppColors.textMuted),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VIDEO PLAYER CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVideoPlayerCard() {
    final bool hasVideo = _selectedFile != null || _videoReady;
    final bool ready = kIsWeb ? _webVideoReady : _videoReady;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Video content
          if (_videoRestoreError)
            _buildVideoPlaceholder(false)
          else if (!hasVideo)
            _buildVideoPlaceholder(false)
          else if (!ready)
              const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accentCyan))
          else if (kIsWeb)
              _webVideo.buildView()
            else
            // Native: AspectRatio keeps the video proportional inside the card
              Center(
                child: AspectRatio(
                  aspectRatio: _video.aspectRatio,
                  child: _video.buildView(),
                ),
              ),

          // ── Overlay controls (shown once video is ready)
          if (hasVideo && ready)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildVideoOverlayControls(),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder(bool loading) {
    final msg = _videoRestoreError
        ? 'Exception Happened\nVideo file could not be loaded.\nIt may have been moved, renamed, or deleted.'
        : loading
        ? 'Loading video…'
        : 'Select a video file to begin';

    final icon = _videoRestoreError
        ? Icons.error_outline_rounded
        : Icons.videocam_off_outlined;

    final color = _videoRestoreError
        ? AppColors.accentMagenta
        : AppColors.textMuted;

    return Container(
      alignment: Alignment.center,
      color: AppColors.surface,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 11, height: 1.5),
        ),
      ]),
    );
  }

  Widget _buildVideoOverlayControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Color(0xCC0A0D12)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppColors.accentCyan,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        ValueListenableBuilder<double>(
          valueListenable: _playhead,
          builder: (_, t, __) => Text(
            '${_fmt(t)} / ${_fmt(_totalDuration)}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 10),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE SCRUBBER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhaseScrubber() {
    if (_segments.isEmpty) {
      return _scrubberPlaceholder('Phase scrubber — appears after analysis');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PHASE SCRUBBER'),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (_, c) {
          return GestureDetector(
            onTapDown: (d) =>
                _seekTo((d.localPosition.dx / c.maxWidth) * _totalDuration),
            onHorizontalDragUpdate: (d) =>
                _seekTo((d.localPosition.dx / c.maxWidth) * _totalDuration),
            child: ValueListenableBuilder<double>(
              valueListenable: _playhead,
              builder: (_, ph, __) => CustomPaint(
                size: Size(c.maxWidth, 36),
                painter: _PhaseScrubberPainter(
                  segments:      _segments,
                  totalDuration: _totalDuration,
                  playhead:      ph,
                  highlighted:   _highlightedPhase,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: _segments
              .map((s) => s.phase)
              .toSet()
              .map((ph) => _LegendDot(
              label: ph,
              color: kPhaseColors[ph] ?? AppColors.textMuted))
              .toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOL SCRUBBER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildToolScrubber() {
    if (_toolOccurrences.isEmpty) {
      return _scrubberPlaceholder('Tool scrubber — appears after analysis');
    }
    final activeToolSet =
    _toolOccurrences.map((o) => o.tool).toSet();
    const laneH  = 7.0;
    const laneGap = 3.0;
    const topPad  = 4.0;
    const botPad  = 18.0;
    final canvasH =
        topPad + activeToolSet.length * (laneH + laneGap) + botPad;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TOOL SCRUBBER'),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (_, c) {
          return GestureDetector(
            onTapDown: (d) =>
                _seekTo((d.localPosition.dx / c.maxWidth) * _totalDuration),
            onHorizontalDragUpdate: (d) =>
                _seekTo((d.localPosition.dx / c.maxWidth) * _totalDuration),
            child: ValueListenableBuilder<double>(
              valueListenable: _playhead,
              builder: (_, ph, __) => CustomPaint(
                size: Size(c.maxWidth, canvasH),
                painter: _ToolScrubberPainter(
                  occurrences:   _toolOccurrences,
                  totalDuration: _totalDuration,
                  playhead:      ph,
                  highlighted:   _highlightedTool,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: kAllTools
              .where((t) => _activeTools.contains(t))
              .map((t) => _LegendDot(label: t, color: _toolColor(t)))
              .toList(),
        ),
      ],
    );
  }

  Widget _scrubberPlaceholder(String hint) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(hint,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 11)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD CONTROLS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUploadControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isAnalyzing ? null : _pickVideo,
                icon: const Icon(Icons.folder_open_rounded, size: 15),
                label: const Text('Select Video'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentCyan,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                (_selectedFile != null && !_isAnalyzing)
                    ? _startAnalysis
                    : null,
                icon: _isAnalyzing
                    ? const SizedBox(
                    width: 13, height: 13,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.play_arrow_rounded, size: 16),
                label:
                Text(_isAnalyzing ? 'Analyzing…' : 'Run Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ]),

          if (_selectedFile != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.video_file_outlined,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(_selectedFile!.name,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ],

          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (_isAnalyzing && _progress == 0) ? null : _progress,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.accentCyan),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: Text(_statusMsg,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ),
            if (_etaString.isNotEmpty)
              Text(_etaString,
                  style: const TextStyle(
                      color: AppColors.accentCyan, fontSize: 11)),
          ]),

          if (_totalDuration > 0) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _miniStat('DURATION', _fmt(_totalDuration)),
                _miniStat('PHASES', '${_segments.length}'),
                _miniStat('TOOLS', '${_activeTools.length}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(children: [
    Text(label,
        style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            letterSpacing: 1)),
    const SizedBox(height: 2),
    Text(value,
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700)),
  ]);

  // ─────────────────────────────────────────────────────────────────────────
  // CURRENT PHASE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhaseCard() {
    final color = kPhaseColors[_currentPhase] ?? AppColors.textMuted;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 14,
              spreadRadius: 1),
        ],
      ),
      child: Row(children: [
        Container(
            width: 4, height: 48,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CURRENT PHASE',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(_currentPhase,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        ConfidenceGaugeWidget(confidence: _phaseConf, color: color),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETECTED TOOLS BADGES
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDetectedToolsBadges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DETECTED TOOLS'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAllTools
              .map((t) => ToolBadgeWidget(
              tool: t, active: _activeTools.contains(t)))
              .toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PHASE DISTRIBUTION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhaseDistribution() {
    final totals = <String, double>{};
    for (final s in _segments) {
      totals[s.phase] = (totals[s.phase] ?? 0) + s.duration;
    }
    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PHASE DISTRIBUTION'),
        const SizedBox(height: 8),
        if (totals.isEmpty)
          Text('No data yet',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.2), fontSize: 13))
        else
          ...totals.entries.map((e) {
            final color = kPhaseColors[e.key] ?? AppColors.textMuted;
            final frac  =
            grandTotal > 0 ? e.value / grandTotal : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(e.key,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11))),
                    Text(
                      '${_fmt(e.value)}  '
                          '${(frac * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: frac,
                      backgroundColor: AppColors.border,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(color),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // If there's no result loaded yet, nothing to regenerate
              if (AnalysisState.instance.lastRaw == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No analysis available. Upload and analyze a video first.'),
                    backgroundColor: AppColors.accentAmber,
                  ),
                );
                return;
              }
              // Re-push the existing raw result back into AnalysisState
              // (in case it was cleared) and switch to the Analysis tab
              final raw = AnalysisState.instance.lastRaw;
              if (raw != null) AnalysisState.instance.setResult(raw);
              widget.onSwitchTab?.call(2);
            },
            icon: const Icon(Icons.analytics_outlined, size: 16),
            label: const Text('Analyze'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.accentCyan,
              side: const BorderSide(color: AppColors.accentCyan),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report download — will be implemented in a future build.'),
                backgroundColor: AppColors.surface,
              ),
            ),
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.accentMagenta,
              side: const BorderSide(color: AppColors.accentMagenta),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────
  String _fmt(double seconds) {
    final t = Duration(seconds: seconds.toInt());
    final m = t.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = t.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _toolColor(String tool) {
    const colors = [
      Color(0xFF4FC3F7), Color(0xFFFFB74D), Color(0xFF81C784),
      Color(0xFFBA68C8), Color(0xFFF06292), Color(0xFF4DB6AC),
      Color(0xFFFFD54F),
    ];
    final idx = kAllTools.indexOf(tool);
    return colors[idx.clamp(0, colors.length - 1)];
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.w600),
  );

  Widget _emptyHint(String text) => Center(
    child: Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.white.withOpacity(0.18),
            fontSize: 12,
            height: 1.6)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Drag handle
// ─────────────────────────────────────────────────────────────────────────────
class _DragHandle extends StatefulWidget {
  final void Function(double dx) onDrag;
  const _DragHandle({required this.onDrag});

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit:  (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 6,
          color: _hovering
              ? AppColors.accentCyan.withOpacity(0.25)
              : Colors.transparent,
          child: Center(
            child: Container(
              width: 2, height: 28,
              decoration: BoxDecoration(
                color: _hovering
                    ? AppColors.accentCyan.withOpacity(0.8)
                    : AppColors.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend dot
// ─────────────────────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final String label;
  final Color  color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 7, height: 7,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 10)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase scrubber painter
// ─────────────────────────────────────────────────────────────────────────────
class _PhaseScrubberPainter extends CustomPainter {
  final List<_PhaseSegment> segments;
  final double              totalDuration;
  final double              playhead;
  final int?                highlighted;

  const _PhaseScrubberPainter({
    required this.segments,
    required this.totalDuration,
    required this.playhead,
    this.highlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration <= 0) return;
    const top = 6.0;
    const h   = 18.0;
    const r   = Radius.circular(3);

    canvas.drawRRect(
        RRect.fromLTRBR(0, top, size.width, top + h, r),
        Paint()..color = const Color(0xFF1E2A3A));

    for (int i = 0; i < segments.length; i++) {
      final s   = segments[i];
      final x1  = (s.startTime / totalDuration) * size.width;
      final x2  = (s.endTime   / totalDuration) * size.width;
      final c   = kPhaseColors[s.phase] ?? const Color(0xFF5A6A7A);
      final hl  = i == highlighted;
      canvas.drawRRect(
        RRect.fromLTRBR(
            x1 + 0.5, top + (hl ? 0 : 3),
            x2 - 0.5, top + h - (hl ? 0 : 3),
            r),
        Paint()..color = c.withOpacity(hl ? 0.95 : 0.6),
      );
    }

    final px = (playhead / totalDuration) * size.width;
    canvas.drawLine(Offset(px, top - 3), Offset(px, top + h + 3),
        Paint()
          ..color       = Colors.white.withOpacity(0.9)
          ..strokeWidth = 1.5);
    final path = Path()
      ..moveTo(px,     top - 7)
      ..lineTo(px + 4, top - 2)
      ..lineTo(px - 4, top - 2)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    void tick(double t, Alignment a) {
      tp.text = TextSpan(
          text: '${(t ~/ 60).toString().padLeft(2, '0')}:'
              '${(t.toInt() % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(
              color: Color(0xFF5A6A7A), fontSize: 9));
      tp.layout();
      final x  = (t / totalDuration) * size.width;
      final dx = a == Alignment.centerLeft
          ? x
          : a == Alignment.centerRight
          ? x - tp.width
          : x - tp.width / 2;
      tp.paint(canvas, Offset(dx, top + h + 3));
    }

    tick(0, Alignment.centerLeft);
    tick(totalDuration / 2, Alignment.center);
    tick(totalDuration, Alignment.centerRight);
  }

  @override
  bool shouldRepaint(_PhaseScrubberPainter o) =>
      o.playhead != playhead ||
          o.highlighted != highlighted ||
          o.segments != segments;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tool scrubber painter — one stacked lane per tool
// ─────────────────────────────────────────────────────────────────────────────
class _ToolScrubberPainter extends CustomPainter {
  final List<_ToolOccurrence> occurrences;
  final double                totalDuration;
  final double                playhead;
  final int?                  highlighted;

  static const _laneH   = 7.0;
  static const _laneGap = 3.0;
  static const _topPad  = 4.0;

  static const _toolColors = [
    Color(0xFF4FC3F7), Color(0xFFFFB74D), Color(0xFF81C784),
    Color(0xFFBA68C8), Color(0xFFF06292), Color(0xFF4DB6AC),
    Color(0xFFFFD54F),
  ];

  const _ToolScrubberPainter({
    required this.occurrences,
    required this.totalDuration,
    required this.playhead,
    this.highlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration <= 0 || occurrences.isEmpty) return;

    final tools   = kAllTools
        .where((t) => occurrences.any((o) => o.tool == t))
        .toList();
    final laneMap = {for (int i = 0; i < tools.length; i++) tools[i]: i};

    for (int i = 0; i < tools.length; i++) {
      final y = _topPad + i * (_laneH + _laneGap);
      canvas.drawRRect(
        RRect.fromLTRBR(0, y, size.width, y + _laneH,
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF1E2A3A),
      );
    }

    for (int idx = 0; idx < occurrences.length; idx++) {
      final occ  = occurrences[idx];
      final lane = laneMap[occ.tool] ?? 0;
      final y    = _topPad + lane * (_laneH + _laneGap);
      final x1   = (occ.startTime / totalDuration) * size.width;
      final x2   = (occ.endTime   / totalDuration) * size.width;
      final ci   =
      kAllTools.indexOf(occ.tool).clamp(0, _toolColors.length - 1);
      final c    = _toolColors[ci];
      final hl   = idx == highlighted;
      canvas.drawRRect(
        RRect.fromLTRBR(
            x1, y + (hl ? 0 : 1.5),
            math.max(x1 + 2, x2), y + _laneH - (hl ? 0 : 1.5),
            const Radius.circular(2)),
        Paint()..color = c.withOpacity(hl ? 1.0 : 0.65),
      );
    }

    final px     = (playhead / totalDuration) * size.width;
    final totalH = _topPad + tools.length * (_laneH + _laneGap);
    canvas.drawLine(
      Offset(px, 0), Offset(px, totalH),
      Paint()
        ..color       = Colors.white.withOpacity(0.8)
        ..strokeWidth = 1.5,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr);
    void tick(double t, Alignment a) {
      tp.text = TextSpan(
          text: '${(t ~/ 60).toString().padLeft(2, '0')}:'
              '${(t.toInt() % 60).toString().padLeft(2, '0')}',
          style: const TextStyle(color: Color(0xFF5A6A7A), fontSize: 9));
      tp.layout();
      final x  = (t / totalDuration) * size.width;
      final dx = a == Alignment.centerLeft
          ? x
          : a == Alignment.centerRight
          ? x - tp.width
          : x - tp.width / 2;
      tp.paint(canvas, Offset(dx, totalH + 2));
    }

    tick(0, Alignment.centerLeft);
    tick(totalDuration / 2, Alignment.center);
    tick(totalDuration, Alignment.centerRight);
  }

  @override
  bool shouldRepaint(_ToolScrubberPainter o) =>
      o.playhead != playhead ||
          o.highlighted != highlighted ||
          o.occurrences != occurrences;
}