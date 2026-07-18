import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../theme/app_constants.dart';
import '../widgets/phase_timeline_widget.dart';
import '../widgets/tool_badge_widget.dart';
import '../widgets/confidence_gauge_widget.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {

  // ── State ─────────────────────────────────────────────────────────────────
  PlatformFile? _selectedFile;
  String?  _currentJobId;
  bool     _isAnalyzing  = false;
  bool     _isConnected  = false;
  double   _progress     = 0.0;
  String   _statusMsg    = 'Select a video to begin analysis';

  // Last completed result
  String       _currentPhase    = '—';
  double       _phaseConfidence = 0.0;
  List<String> _activeTools     = [];
  List<Map<String, dynamic>> _timeline = [];

  StreamSubscription<Map<String, dynamic>>? _pollSub;

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  DateTime? _analysisStartTime;
  String    _etaString = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _checkConnection();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollSub?.cancel();
    super.dispose();
  }

  // ── Backend check ─────────────────────────────────────────────────────────
  Future<void> _checkConnection() async {
    final alive = await ApiService.isBackendAlive();
    if (mounted) setState(() => _isConnected = alive);
  }

  // ── Pick video ────────────────────────────────────────────────────────────
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: kIsWeb,       // load bytes into memory only on web
      withReadStream: false,
    );
    if (result != null) {
      setState(() {
        _selectedFile    = result.files.single;
        _statusMsg       = 'Loaded: ${_selectedFile!.name}';
        _timeline.clear();
        _currentPhase    = '—';
        _phaseConfidence = 0.0;
        _activeTools     = [];
        _progress        = 0.0;
      });
    }
  }

  // ── Submit + poll ─────────────────────────────────────────────────────────
  Future<void> _startAnalysis() async {
    if (_selectedFile == null) return;
    setState(() {
      _isAnalyzing      = true;
      _statusMsg        = 'Uploading video…';
      _timeline.clear();
      _progress         = 0.0;
      _etaString        = '';
      _analysisStartTime = null;   // reset
    });

    try {
      final jobId = await ApiService.submitVideo(_selectedFile!);
      setState(() {
        _currentJobId = jobId;
        _statusMsg    = 'Processing…';
      });
      _pollSub = ApiService.pollUntilDone(jobId).listen(
        _handleUpdate,
        onError: (e) => _setError('Polling error: $e'),
      );
    } catch (e) {
      _setError('$e');
    }
  }

  void _handleUpdate(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      final newProgress =
          (data['progress'] as num?)?.toDouble() ?? _progress;

      // Start timing once real progress begins
      if (newProgress > 0.0 && _analysisStartTime == null) {
        _analysisStartTime = DateTime.now();
      }

      // Estimate remaining time
      if (_analysisStartTime != null && newProgress > 0.01) {
        final elapsed =
            DateTime.now().difference(_analysisStartTime!).inSeconds;

        final totalEstimated = elapsed / newProgress;
        final remaining =
        (totalEstimated - elapsed).clamp(0, double.infinity).toInt();

        if (remaining < 60) {
          _etaString = 'ETA: ~$remaining s remaining';
        } else {
          final mins = remaining ~/ 60;
          final secs = remaining % 60;
          _etaString = 'ETA: ~${mins}m ${secs}s remaining';
        }
      }

      _progress = newProgress;
      _statusMsg =
      'Processing… ${(_progress * 100).toStringAsFixed(0)}%';

      if (data['status'] == 'done') {
        _isAnalyzing = false;
        _etaString = '';

        final raw = data['result'] as Map<String, dynamic>;

        // Build timeline entries from phase_timeline
        _timeline = (raw['phase_timeline'] as List)
            .map((p) => {
          'phase': p['phase'],
          'phase_conf': 1.0,
          'tools': <String>[],
          'frame_idx': 0,
        })
            .toList();

        // Show the latest detected phase
        if (_timeline.isNotEmpty) {
          _currentPhase = _timeline.last['phase'] as String;
          _phaseConfidence = 1.0;
        }

        // Display detected tools
        _activeTools = (raw['tools_detected'] as List)
            .map((t) => t['tool'] as String)
            .toList();

        _progress = 1.0;
        _statusMsg =
        'Analysis complete — ${_timeline.length} phases detected';
      }

      if (data['status'] == 'error') {
        _setError(data['error'] as String? ?? 'Unknown backend error');
        _etaString = '';
      }
    });
  }

  void _setError(String msg) {
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _statusMsg   = '⚠ $msg';
    });
    _pollSub?.cancel();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Narrow screen (phone/tablet): single scrollable column
                if (constraints.maxWidth < 600) {
                  return _buildMobileLayout();
                }
                // Wide screen (desktop/web): three-column layout
                return _buildDesktopLayout();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(width: 320, child: _buildLeftPanel()),
        const VerticalDivider(color: Color(0xFF1E2A3A), width: 1),
        Expanded(child: _buildCenterPanel()),
        const VerticalDivider(color: Color(0xFF1E2A3A), width: 1),
        SizedBox(width: 280, child: _buildRightPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls block
          _buildLeftPanel(),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1E2A3A)),
          const SizedBox(height: 16),
          // Phase card + tools
          _sectionLabel('LIVE ANALYSIS'),
          const SizedBox(height: 12),
          _buildPhaseCard(),
          const SizedBox(height: 16),
          _buildToolsRow(),
          const SizedBox(height: 16),
          // Phase distribution (fixed height on mobile)
          _sectionLabel('PHASE DISTRIBUTION'),
          const SizedBox(height: 10),
          ..._buildPhaseDistributionList(),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1E2A3A)),
          const SizedBox(height: 16),
          // Timeline
          _sectionLabel('PHASE TIMELINE'),
          const SizedBox(height: 10),
          _buildTimelineList(),
        ],
      ),
    );
  }

  // These helpers let the mobile layout reuse center/right panel content
  // without the Expanded wrappers that only work inside Flex widgets.
  List<Widget> _buildPhaseDistributionList() {
    final phaseCounts = <String, int>{};
    for (final e in _timeline) {
      final p = e['phase'] as String? ?? '—';
      phaseCounts[p] = (phaseCounts[p] ?? 0) + 1;
    }
    if (phaseCounts.isEmpty) {
      return [
        Text('No data yet',
            style: TextStyle(
                color: Colors.white.withOpacity(0.2), fontSize: 13))
      ];
    }
    return phaseCounts.entries.toList().reversed
        .map((e) => _buildPhaseBar(e.key, e.value, _timeline.length))
        .toList();
  }

  Widget _buildTimelineList() {
    if (_timeline.isEmpty) {
      return Text(
        'Timeline will appear once analysis completes',
        style: TextStyle(
            color: Colors.white.withOpacity(0.2), fontSize: 12, height: 1.6),
      );
    }
    return Column(
      children: _timeline.reversed
          .take(20) // cap at 20 on mobile to avoid huge scroll
          .map((entry) => PhaseTimelineWidget(entry: entry))
          .toList(),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 56,
      color: const Color(0xFF0D1421),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.biotech, color: Color(0xFF00BCD4), size: 22),
          const SizedBox(width: 10),
          const Text('ORAS',
              style: TextStyle(
                  color: Color(0xFF00BCD4),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4)),
          const SizedBox(width: 8),
          const Text('Operative Recognition & Analysis System',
              style: TextStyle(color: Color(0xFF5A6A7A), fontSize: 12)),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, __) => Opacity(
              opacity: _isConnected ? _pulseAnimation.value : 1.0,
              child: Row(children: [
                Icon(Icons.circle,
                    size: 8,
                    color: _isConnected
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFF44336)),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Backend Online' : 'Backend Offline',
                  style: TextStyle(
                      color: _isConnected
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                      fontSize: 12),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 16, color: Color(0xFF5A6A7A)),
                  onPressed: _checkConnection,
                  tooltip: 'Recheck backend',
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Left panel ────────────────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    return Container(
      color: const Color(0xFF0D1421),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionLabel('VIDEO INPUT'),
          const SizedBox(height: 12),

          // Pick button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _pickVideo,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Select Video File'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00BCD4),
                side: const BorderSide(color: Color(0xFF1E2A3A)),
              ),
            ),
          ),

          if (_selectedFile != null) ...[
            const SizedBox(height: 10),
            Text(
              _selectedFile!.name,
              style: const TextStyle(color: Color(0xFF8A9AB0), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),
          _sectionLabel('PIPELINE CONTROLS'),
          const SizedBox(height: 12),

          // Analyze button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_selectedFile != null && !_isAnalyzing)
                  ? _startAnalysis
                  : null,
              icon: _isAnalyzing
                  ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow, size: 16),
              label: Text(_isAnalyzing ? 'Analyzing…' : 'Run Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 20),
          _sectionLabel('STATUS'),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _isAnalyzing && _progress == 0 ? null : _progress,
              backgroundColor: const Color(0xFF1E2A3A),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(_statusMsg,
              style: const TextStyle(color: Color(0xFF5A6A7A), fontSize: 11)),
          Text(_statusMsg,
              style: const TextStyle(color: Color(0xFF5A6A7A), fontSize: 11)),
          // ── ADD THIS ──
          if (_etaString.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _etaString,
              style: const TextStyle(color: Color(0xFF4FD1E8), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  // ── Center panel ──────────────────────────────────────────────────────────
  Widget _buildCenterPanel() {
    return Container(
      color: const Color(0xFF0A0E1A),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('LIVE ANALYSIS'),
          const SizedBox(height: 16),
          _buildPhaseCard(),
          const SizedBox(height: 16),
          _buildToolsRow(),
          const SizedBox(height: 16),
          Expanded(child: _buildStatsGrid()),
        ],
      ),
    );
  }

  Widget _buildPhaseCard() {
    final color = kPhaseColors[_currentPhase] ?? const Color(0xFF5A6A7A);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1421),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('CURRENT PHASE',
                  style: TextStyle(
                      color: Color(0xFF5A6A7A), fontSize: 10, letterSpacing: 2)),
              const SizedBox(height: 6),
              Text(_currentPhase,
                  style: TextStyle(
                      color: color, fontSize: 20, fontWeight: FontWeight.w600)),
            ]),
          ),
          ConfidenceGaugeWidget(confidence: _phaseConfidence, color: color),
        ],
      ),
    );
  }

  Widget _buildToolsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DETECTED TOOLS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kAllTools
              .map((t) => ToolBadgeWidget(tool: t, active: _activeTools.contains(t)))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final phaseCounts = <String, int>{};
    for (final e in _timeline) {
      final p = e['phase'] as String? ?? '—';
      phaseCounts[p] = (phaseCounts[p] ?? 0) + 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('PHASE DISTRIBUTION'),
        const SizedBox(height: 10),
        Expanded(
          child: phaseCounts.isEmpty
              ? Center(
              child: Text('No data yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.2), fontSize: 13)))
              : ListView(
            children: phaseCounts.entries.toList().reversed
                .map((e) => _buildPhaseBar(e.key, e.value, _timeline.length))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseBar(String phase, int count, int total) {
    final color = kPhaseColors[phase] ?? const Color(0xFF5A6A7A);
    final frac  = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(phase,
                    style: const TextStyle(
                        color: Color(0xFF8A9AB0), fontSize: 11))),
            Text('${(frac * 100).toStringAsFixed(1)}%',
                style: TextStyle(color: color, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              backgroundColor: const Color(0xFF1E2A3A),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Right panel — timeline ─────────────────────────────────────────────────
  Widget _buildRightPanel() {
    return Container(
      color: const Color(0xFF0D1421),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: _sectionLabel('PHASE TIMELINE'),
          ),
          Expanded(
            child: _timeline.isEmpty
                ? Center(
                child: Text(
                    'Timeline will appear\nonce analysis completes',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 12,
                        height: 1.6)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _timeline.length,
              reverse: true,
              itemBuilder: (_, i) {
                final entry = _timeline[_timeline.length - 1 - i];
                return PhaseTimelineWidget(entry: entry);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
        color: Color(0xFF3A5A6A),
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.w600),
  );
}