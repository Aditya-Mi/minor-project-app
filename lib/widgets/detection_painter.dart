import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Uint8List imageBytes;

  DetectionPainter({required this.detections, required this.imageBytes});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    // Get original image dimensions (assuming server sends 640x480 as configured)
    const originalWidth = 640.0;
    const originalHeight = 480.0;

    // Calculate scale factors based on the display size vs original image size
    final double scaleX = size.width / originalWidth;
    final double scaleY = size.height / originalHeight;
    final scale =
    math.min(scaleX, scaleY); // Use minimum scale to maintain aspect ratio

    // Calculate offset to center the image
    final double offsetX = (size.width - (originalWidth * scale)) / 2;
    final double offsetY = (size.height - (originalHeight * scale)) / 2;

    for (final detection in detections) {
      final bbox = List<double>.from(detection['bbox']);
      final confidence = detection['confidence'] as double;

      // Scale the bounding box to match the display size
      final rect = Rect.fromLTRB(
        offsetX + (bbox[0] * scale),
        offsetY + (bbox[1] * scale),
        offsetX + (bbox[2] * scale),
        offsetY + (bbox[3] * scale),
      );

      canvas.drawRect(rect, paint);

      // Draw the confidence text
      textPainter.text = TextSpan(
        text: 'Person ${(confidence * 100).toStringAsFixed(1)}%',
        style: const TextStyle(
          color: Colors.green,
          fontSize: 12,
          backgroundColor: Colors.black54,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, math.max(0, rect.top - 15)));
    }
  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) => true;
}