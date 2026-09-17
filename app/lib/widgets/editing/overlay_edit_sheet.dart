import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/timeline_overlay.dart';
import '../../theme/app_colors.dart';

/// Bottom sheet for creating or editing a text/image overlay. Returns
/// the resulting TimelineOverlay via Navigator.pop, or null if
/// cancelled. Pass [existing] to edit, omit it to create a new [type].
class OverlayEditSheet extends StatefulWidget {
  final OverlayType type;
  final TimelineOverlay? existing;
  final double defaultStartSeconds;
  final double maxDurationSeconds;

  const OverlayEditSheet({
    super.key,
    required this.type,
    this.existing,
    required this.defaultStartSeconds,
    required this.maxDurationSeconds,
  });

  static Future<TimelineOverlay?> show(
      BuildContext context, {
        required OverlayType type,
        TimelineOverlay? existing,
        required double defaultStartSeconds,
        required double maxDurationSeconds,
      }) {
    return showModalBottomSheet<TimelineOverlay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => OverlayEditSheet(
        type: type,
        existing: existing,
        defaultStartSeconds: defaultStartSeconds,
        maxDurationSeconds: maxDurationSeconds,
      ),
    );
  }

  @override
  State<OverlayEditSheet> createState() => _OverlayEditSheetState();
}

class _OverlayEditSheetState extends State<OverlayEditSheet> {
  late TextEditingController _textCtrl;
  late double _start;
  late double _duration;
  String? _imagePath;
  double _fontSize = 24;

  static const _colors = ['#FFFFFF', '#FFD54F', '#4FD1E8', '#E8447A', '#3DDC97'];
  String _colorHex = '#FFFFFF';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _textCtrl = TextEditingController(text: e?.content ?? '');
    _start = e?.startSeconds ?? widget.defaultStartSeconds;
    _duration = e?.durationSeconds ?? 3.0;
    _fontSize = e?.fontSize ?? 24;
    _colorHex = e?.colorHex ?? '#FFFFFF';
    _imagePath = widget.type == OverlayType.image ? e?.content : null;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    setState(() => _imagePath = result.files.single.path);
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

  void _save() {
    final content =
    widget.type == OverlayType.text ? _textCtrl.text.trim() : _imagePath;
    if (content == null || content.isEmpty) return;

    final overlay = TimelineOverlay(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: widget.type,
      content: content,
      startSeconds: _start,
      durationSeconds: _duration,
      x: widget.existing?.x ?? 0.35,
      y: widget.existing?.y ?? 0.4,
      fontSize: widget.type == OverlayType.text ? _fontSize : null,
      colorHex: widget.type == OverlayType.text ? _colorHex : null,
    );
    Navigator.pop(context, overlay);
  }

  @override
  Widget build(BuildContext context) {
    final maxStart =
    (widget.maxDurationSeconds - 0.5).clamp(0.0, double.infinity);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.type == OverlayType.text
                      ? (widget.existing == null ? 'Add Text' : 'Edit Text')
                      : (widget.existing == null ? 'Add Image' : 'Edit Image'),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.type == OverlayType.text) ...[
              TextField(
                controller: _textCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Enter text…',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Size',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _fontSize,
                      min: 12,
                      max: 64,
                      activeColor: AppColors.accentCyan,
                      inactiveColor: AppColors.border,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                  Text('${_fontSize.toInt()}',
                      style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              Row(
                children: _colors.map((c) {
                  final selected = c == _colorHex;
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                          selected ? AppColors.accentCyan : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ] else ...[
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: _imagePath == null
                      ? const Text('Tap to choose an image',
                      style:
                      TextStyle(color: AppColors.textMuted, fontSize: 12))
                      : Text(_basename(_imagePath!),
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Appears at ${_fmt(_start)} for ${_duration.toStringAsFixed(1)}s',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            Slider(
              value: _start,
              min: 0,
              max: maxStart > 0 ? maxStart : 1,
              activeColor: AppColors.accentCyan,
              inactiveColor: AppColors.border,
              onChanged: maxStart > 0 ? (v) => setState(() => _start = v) : null,
            ),
            Row(
              children: [
                const Text('Duration',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                Expanded(
                  child: Slider(
                    value: _duration,
                    min: 0.5,
                    max: 15,
                    activeColor: AppColors.accentCyan,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _duration = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border)),
                    child: const Text('Cancel',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: AppColors.background),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}