import 'package:flutter/material.dart';
import '../../theme/app_constants.dart';

class PhaseTimelineWidget extends StatelessWidget {
  final Map<String, dynamic> entry;

  const PhaseTimelineWidget({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final phase    = entry['phase']      as String? ?? '—';
    final conf     = (entry['phase_conf'] as num?)?.toDouble() ?? 0.0;
    final tools    = List<String>.from(entry['tools'] ?? []);
    final frameIdx = entry['frame_idx']  as int?    ?? 0;
    final color    = kPhaseColors[phase] ?? const Color(0xFF5A6A7A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Container(width: 1, height: 40, color: const Color(0xFF1E2A3A)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(phase,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      Text('f$frameIdx',
                          style: const TextStyle(
                              color: Color(0xFF3A4A5A), fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text('${(conf * 100).toStringAsFixed(0)}% conf',
                          style: const TextStyle(
                              color: Color(0xFF5A6A7A), fontSize: 10)),
                      if (tools.isNotEmpty) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: Color(0xFF3A4A5A), fontSize: 10)),
                        Expanded(
                          child: Text(tools.join(', '),
                              style: const TextStyle(
                                  color: Color(0xFF5A6A7A), fontSize: 10),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}