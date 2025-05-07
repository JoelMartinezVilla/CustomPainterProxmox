import 'package:flutter/material.dart';
import '../models/file_entry.dart';

class FileListPainter extends CustomPainter {
  final List<FileEntry> fileList;
  final double lineHeight;
  final int? selectedIndex;

  const FileListPainter({
    required this.fileList,
    required this.lineHeight,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const fileStyle = TextStyle(color: Colors.black87, fontSize: 16);
    final dirStyle = TextStyle(
      color: Colors.blue.shade800,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    const parentStyle = TextStyle(
      color: Colors.redAccent,
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    double y = 20; // Margen superior

    for (var i = 0; i < fileList.length; i++) {
      final entry = fileList[i];
      if (selectedIndex != null && selectedIndex == i) {
        final highlight = Paint()..color = Colors.yellow.withOpacity(0.3);
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, lineHeight), highlight);
      }

      final display = entry.name == '..'
          ? '⬆️ ..'
          : entry.isDirectory
              ? '📁 ${entry.name}'
              : '📄 ${entry.name}';
      final style = entry.name == '..'
          ? parentStyle
          : entry.isDirectory
              ? dirStyle
              : fileStyle;

      textPainter.text = TextSpan(text: display, style: style);
      textPainter.layout(maxWidth: size.width - 20);
      textPainter.paint(canvas, Offset(10, y));
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant FileListPainter old) =>
      old.fileList != fileList || old.selectedIndex != selectedIndex;
}
