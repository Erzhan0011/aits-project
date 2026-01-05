import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlaneEmblem extends StatefulWidget {
  final double size;
  const PlaneEmblem({super.key, this.size = 200});

  @override
  State<PlaneEmblem> createState() => _PlaneEmblemState();
}

class _PlaneEmblemState extends State<PlaneEmblem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _PlaneEmblemPainter(_controller.value),
          );
        },
      ),
    );
  }
}

class _PlaneEmblemPainter extends CustomPainter {
  final double progress;
  _PlaneEmblemPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF38BDF8);

    // Subtle glow
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, size.width * 0.3, glowPaint);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    
    // Smooth floating animation
    final floatOffset = math.sin(progress * 2 * math.pi) * 10;
    canvas.translate(0, floatOffset);

    // Modern Minimalist Plane Path
    final path = Path()
      ..moveTo(0, -size.height * 0.3) // Nose
      ..lineTo(-size.width * 0.05, -size.height * 0.1)
      ..lineTo(-size.width * 0.3, size.height * 0.1) // Left wing
      ..lineTo(-size.width * 0.05, size.height * 0.05)
      ..lineTo(-size.width * 0.05, size.height * 0.2)
      ..lineTo(-size.width * 0.15, size.height * 0.3) // Tail left
      ..lineTo(0, size.height * 0.25)
      ..lineTo(size.width * 0.15, size.height * 0.3) // Tail right
      ..lineTo(size.width * 0.05, size.height * 0.2)
      ..lineTo(size.width * 0.05, size.height * 0.05)
      ..lineTo(size.width * 0.3, size.height * 0.1) // Right wing
      ..lineTo(size.width * 0.05, -size.height * 0.1)
      ..close();

    // Draw with gradient
    final rect = Rect.fromCenter(center: Offset.zero, width: size.width, height: size.height);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
    ).createShader(rect);

    canvas.drawPath(path, paint);
    
    // Inner highlight
    final highlightPath = Path()
      ..moveTo(0, -size.height * 0.25)
      ..lineTo(-size.width * 0.02, -size.height * 0.1)
      ..lineTo(-size.width * 0.02, size.height * 0.15)
      ..lineTo(0, size.height * 0.18)
      ..lineTo(size.width * 0.02, size.height * 0.15)
      ..lineTo(size.width * 0.02, -size.height * 0.1)
      ..close();
    
    canvas.drawPath(highlightPath, Paint()..color = Colors.white.withOpacity(0.2));
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlaneEmblemPainter oldDelegate) => true;
}
