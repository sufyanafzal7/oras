import 'package:flutter/material.dart';
import '../models/edit_timeline.dart';
import '../models/stored_procedure.dart';
import '../models/timeline_clip.dart';
import '../services/edit_timeline_store.dart';
import '../services/procedure_store.dart';
import '../theme/app_colors.dart';
import '../widgets/editing/timeline_card.dart';
import '../widgets/editing/timestamp_range_row.dart';
import 'video_editor_screen.dart';

/// Tab 4 — Video Editing.
///
/// Scoped entirely to ProcedureStore.instance.selectedProcedure:
///   • No video selected            -> prompt to pick one from Dashboard.
///   • Selected video, 0 timelines  -> "create new" form (timestamp
///                                     ranges + Add Timestamp + Import).
///   • Selected video, 1+ timelines -> grid of that video's saved
///                                     timeline cards, with a "+ New
///                                     Timeline" tile that reveals the
///                                     same form (up to the 10 cap).
class VideoEditingTabScreen extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;

  const VideoEditingTabScreen({super.key, this.onSwitchTab});

  @override
  State<VideoEditingTabScreen> createState() => _VideoEditingTabScreenState();
}

class _VideoEditingTabScreenState extends State<VideoEditingTabScreen> {
  bool _showCreateForm = false;
  final List<_DraftRange> _drafts = [_DraftRange()];

  @override
  void initState() {
    super.initState();
    ProcedureStore.instance.addListener(_onChange);
    EditTimelineStore.instance.addListener(_onChange);
  }

  @override
  void dispose() {
    ProcedureStore.instance.removeListener(_onChange);
    EditTimelineStore.instance.removeListener(_onChange);
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _resetDrafts() {
    for (final d in _drafts) {
      d.dispose();
    }
    _drafts
      ..clear()
      ..add(_DraftRange());
  }

  @override
  Widget build(BuildContext context) {
    final procedure = ProcedureStore.instance.activeProcedure;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(procedure),
          Expanded(
            child: procedure == null
                ? _buildNoSelectionState()
                : _buildForProcedure(procedure.id, procedure),
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar(StoredProcedure? procedure) {
    return Container(
      height: 52,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.content_cut_rounded,
              color: AppColors.accentCyan, size: 18),
          const SizedBox(width: 8),
          const Text('Video Editing',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (procedure != null)
            Expanded(
              child: Text(
                procedure.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  // ── No video selected ────────────────────────────────────────────────────
  Widget _buildNoSelectionState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.content_cut_rounded,
                color: AppColors.accentCyan, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No video selected',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Select a processed video from the Dashboard\nto start building an editing timeline for it.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          if (widget.onSwitchTab != null)
            TextButton.icon(
              onPressed: () => widget.onSwitchTab!(0),
              icon: const Icon(Icons.grid_view_rounded,
                  size: 16, color: AppColors.accentCyan),
              label: const Text('Go to Dashboard',
                  style: TextStyle(color: AppColors.accentCyan)),
            ),
        ],
      ),
    );
  }

  // ── Has a selected video ─────────────────────────────────────────────────
  Widget _buildForProcedure(String procedureId, StoredProcedure procedure) {
    final timelines = EditTimelineStore.instance.timelinesFor(procedureId);

    if (timelines.isEmpty || _showCreateForm) {
      return _buildCreateForm(procedureId, procedure,
          showBack: timelines.isNotEmpty);
    }
    return _buildTimelineGrid(procedureId, timelines);
  }

  // ── Timeline card grid ───────────────────────────────────────────────────
  Widget _buildTimelineGrid(
      String procedureId, List<EditTimeline> timelines) {
    final canAddMore = EditTimelineStore.instance.canAddMoreFor(procedureId);

    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 900
          ? 4
          : constraints.maxWidth > 600
          ? 3
          : 2;
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: timelines.length + 1, // +1 for the "new timeline" tile
        itemBuilder: (context, index) {
          if (index == timelines.length) {
            return _NewTimelineTile(
              enabled: canAddMore,
              onTap: canAddMore
                  ? () {
                _resetDrafts();
                setState(() => _showCreateForm = true);
              }
                  : null,
            );
          }
          final t = timelines[index];
          return TimelineCard(
            timeline: t,
            onTap: () => _openEditor(t),
            onDelete: () => _confirmDelete(t),
          );
        },
      );
    });
  }

  // ── Create-new form ───────────────────────────────────────────────────────
  Widget _buildCreateForm(String procedureId, StoredProcedure procedure,
      {required bool showBack}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack)
            TextButton.icon(
              onPressed: () => setState(() => _showCreateForm = false),
              icon: const Icon(Icons.arrow_back_rounded,
                  size: 16, color: AppColors.textMuted),
              label: const Text('Back to timelines',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          const Text('New Timeline',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Mark the sections of the video you want to pull into the '
                'editor. Each range becomes a clip, stitched in order.',
            style:
            TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.5),
          ),
          const SizedBox(height: 16),
          ...List.generate(_drafts.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TimestampRangeRow(
                index: i,
                startController: _drafts[i].startCtrl,
                endController: _drafts[i].endCtrl,
                errorText: _drafts[i].error,
                onRemove: _drafts.length > 1
                    ? () => setState(() {
                  _drafts[i].dispose();
                  _drafts.removeAt(i);
                })
                    : null,
              ),
            );
          }),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() => _drafts.add(_DraftRange())),
            icon: const Icon(Icons.add_rounded,
                size: 16, color: AppColors.accentCyan),
            label: const Text('Add Timestamp',
                style: TextStyle(color: AppColors.accentCyan)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _import(procedureId, procedure),
              icon: const Icon(Icons.movie_creation_outlined, size: 18),
              label: const Text('Import'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _import(String procedureId, StoredProcedure procedure) async {
    final clips = <TimelineClip>[];
    var hasError = false;

    setState(() {
      for (final d in _drafts) {
        final start = _parseTimestamp(d.startCtrl.text);
        final end = _parseTimestamp(d.endCtrl.text);
        d.error = null;

        if (start == null || end == null) {
          d.error = 'Use HH:MM:SS or MM:SS';
          hasError = true;
        } else if (end <= start) {
          d.error = 'End must be after start';
          hasError = true;
        } else if (procedure.durationSeconds > 0 &&
            end > procedure.durationSeconds) {
          d.error = 'Beyond video length';
          hasError = true;
        } else {
          clips.add(TimelineClip(
            id: '${DateTime.now().microsecondsSinceEpoch}_${clips.length}',
            startSeconds: start,
            endSeconds: end,
          ));
        }
      }
    });

    if (hasError || clips.isEmpty) return;

    final now = DateTime.now();
    final existingCount = EditTimelineStore.instance.countFor(procedureId);
    final timeline = EditTimeline(
      id: now.microsecondsSinceEpoch.toString(),
      sourceProcedureId: procedureId,
      sourceJobId: procedure.jobId,
      sourceFilePath: procedure.filePath,
      sourceFileName: procedure.fileName,
      name: 'Timeline ${existingCount + 1}',
      clips: clips,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await EditTimelineStore.instance.add(timeline);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$e'), backgroundColor: AppColors.accentMagenta),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _showCreateForm = false);
      _openEditor(timeline);
    }
  }

  void _openEditor(EditTimeline timeline) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VideoEditorScreen(timeline: timeline)),
    );
  }

  void _confirmDelete(EditTimeline timeline) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete timeline?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${timeline.name}" will be permanently deleted.',
            style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              EditTimelineStore.instance.remove(timeline.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.accentMagenta)),
          ),
        ],
      ),
    );
  }

  /// Parses "HH:MM:SS", "MM:SS" or a bare seconds count into seconds.
  double? _parseTimestamp(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final parts = s.split(':').map((p) => p.trim()).toList();
    try {
      if (parts.length == 3) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final sec = double.parse(parts[2]);
        return h * 3600 + m * 60 + sec;
      } else if (parts.length == 2) {
        final m = int.parse(parts[0]);
        final sec = double.parse(parts[1]);
        return m * 60 + sec;
      } else if (parts.length == 1) {
        return double.parse(parts[0]);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

// ── Private helpers ────────────────────────────────────────────────────────

class _DraftRange {
  final TextEditingController startCtrl = TextEditingController();
  final TextEditingController endCtrl = TextEditingController();
  String? error;

  void dispose() {
    startCtrl.dispose();
    endCtrl.dispose();
  }
}

class _NewTimelineTile extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _NewTimelineTile({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled
                ? AppColors.accentCyan.withValues(alpha: 0.3)
                : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 28,
                color: enabled ? AppColors.accentCyan : AppColors.textMuted),
            const SizedBox(height: 6),
            Text(
              enabled ? 'New Timeline' : 'Max 10 reached',
              style: TextStyle(
                  color: enabled ? AppColors.accentCyan : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}