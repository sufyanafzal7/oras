import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// One start/end timestamp input pair inside the "New Timeline" form.
/// Accepts HH:MM:SS, MM:SS, or a bare seconds value — parsing/validation
/// happens in the parent screen; this widget just renders the fields
/// and surfaces [errorText] underneath when set.
class TimestampRangeRow extends StatelessWidget {
  final int index;
  final TextEditingController startController;
  final TextEditingController endController;
  final String? errorText;
  final VoidCallback? onRemove;

  const TimestampRangeRow({
    super.key,
    required this.index,
    required this.startController,
    required this.endController,
    this.errorText,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('${index + 1}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ),
            Expanded(child: _field(startController, 'Start  00:00:00')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded,
                  size: 14, color: AppColors.textMuted),
            ),
            Expanded(child: _field(endController, 'End  00:00:00')),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textMuted),
                onPressed: onRemove,
                splashRadius: 16,
              )
            else
              const SizedBox(width: 40),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Text(errorText!,
                style: const TextStyle(
                    color: AppColors.accentMagenta, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _field(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accentCyan),
        ),
      ),
    );
  }
}