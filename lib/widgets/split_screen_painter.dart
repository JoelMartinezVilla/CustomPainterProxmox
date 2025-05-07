import 'package:flutter/material.dart';

class SplitScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fondo panel izquierdo
    final leftRect = Rect.fromLTWH(0, 0, size.width / 2, size.height);
    final leftPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomLeft,
      ).createShader(leftRect);
    canvas.drawRect(leftRect, leftPaint);

    // Fondo panel derecho
    final rightRect =
        Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
    final rightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        begin: Alignment.topRight,
        end: Alignment.bottomRight,
      ).createShader(rightRect);
    canvas.drawRect(rightRect, rightPaint);

    // Divisor vertical
    final divider = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      divider,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
