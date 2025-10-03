import 'package:flutter/material.dart';
import 'package:snackflix/services/chewing_detection_service.dart';

class OverlayPainter extends CustomPainter {
  final Rect? mouthBox;
  final List<DetVis> dets;

  OverlayPainter({required this.mouthBox, required this.dets});

  @override
  void paint(Canvas canvas, Size size) {
    final pMouth = Paint()
      ..color = const Color(0xAA00FF88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pObjNear = Paint()
      ..color = const Color(0xAAFFCC00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final pObjFar = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (mouthBox != null) {
      canvas.drawRect(mouthBox!, pMouth);
    }

    void textPainter(String s, Offset at) {
      final tp = TextPainter(
        text: TextSpan(
            style: const TextStyle(color: Colors.white, fontSize: 10),
            text: s),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 180);
      tp.paint(canvas, at);
    }

    for (final d in dets) {
      canvas.drawRect(d.box, d.near ? pObjNear : pObjFar);
      final label =
          '${d.id ?? '-'} ${d.label} ${(d.conf * 100).toStringAsFixed(0)}% '
          'iou:${d.iou.toStringAsFixed(2)} d:${d.dist.toStringAsFixed(0)}${d.movingCloser ? "→" : ""}';
      textPainter(label, d.box.topLeft + const Offset(2, -12));
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.mouthBox != mouthBox || oldDelegate.dets != dets;
  }
}