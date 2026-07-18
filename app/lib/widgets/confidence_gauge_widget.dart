import 'dart:math' as math;
import 'package:flutter/material.dart';

class ConfidenceGaugeWidget extends StatelessWidget {
  final double confidence;
  final Color  color;

  const ConfidenceGaugeWidget({
    super.key,
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(64, 64),
            painter: _GaugePainter(confidence: confidence, color: color),
          ),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double confidence;
  final Color  color;

  _GaugePainter({required this.confidence, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 4;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..color       = const Color(0xFF1E2A3A)
        ..strokeWidth = 5
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi * 0.75,
      math.pi * 1.5 * confidence.clamp(0.0, 1.0),
      false,
      Paint()
        ..color       = color
        ..strokeWidth = 5
        ..style       = PaintingStyle.stroke
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.confidence != confidence || old.color != color;
}