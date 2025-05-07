import 'package:flutter/material.dart';

class BlueBarPainter extends CustomPainter {
  final bool connected;
  final int? port;

  const BlueBarPainter({required this.connected, this.port});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.blue;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final circle = Paint()..color = connected ? Colors.green : Colors.red;
    final r = size.height * 0.25;
    final c = Offset(r * 2, size.height / 2);
    canvas.drawCircle(c, r, circle);

    final msg = connected
        ? 'Servidor NodeJS funcionando en el puerto $port'
        : 'ERROR: El servidor NodeJS no está funcionando';

    final textPainter = TextPainter(
      text: TextSpan(
        text: msg,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.3,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width);
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant BlueBarPainter old) =>
      old.connected != connected || old.port != port;
}
