import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Multi-colour Google "G" logo drawn with CustomPaint (no asset needed).
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: const _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  double _deg(double d) => d * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.2;
    final center = Offset(w / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: (w - stroke) / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // Angles: 0° = 3 o'clock, clockwise. Gap of the "G" is from -45° to 0°.
    paint.color = _blue;
    canvas.drawArc(rect, _deg(0), _deg(45), false, paint);
    paint.color = _green;
    canvas.drawArc(rect, _deg(45), _deg(95), false, paint);
    paint.color = _yellow;
    canvas.drawArc(rect, _deg(140), _deg(80), false, paint);
    paint.color = _red;
    canvas.drawArc(rect, _deg(220), _deg(95), false, paint);

    // Horizontal blue bar of the "G".
    canvas.drawRect(
      Rect.fromLTWH(w / 2, center.dy - stroke / 2, w / 2, stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
