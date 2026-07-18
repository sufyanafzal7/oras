import 'package:flutter/material.dart';

const Map<String, IconData> kToolIcons = {
  'grasper':     Icons.back_hand,
  'bipolar':     Icons.electric_bolt,
  'hook':        Icons.architecture,
  'scissors':    Icons.content_cut,
  'clipper':     Icons.compress,
  'irrigator':   Icons.water_drop,
  'specimenbag': Icons.inventory_2,
};

class ToolBadgeWidget extends StatelessWidget {
  final String tool;
  final bool   active;

  const ToolBadgeWidget({super.key, required this.tool, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF00BCD4).withOpacity(0.15)
            : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFF00BCD4) : const Color(0xFF1E2A3A),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kToolIcons[tool] ?? Icons.hardware,
            size: 12,
            color: active ? const Color(0xFF00BCD4) : const Color(0xFF2A3A4A),
          ),
          const SizedBox(width: 5),
          Text(
            tool,
            style: TextStyle(
              color: active ? const Color(0xFFCFD8DC) : const Color(0xFF2A3A4A),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}