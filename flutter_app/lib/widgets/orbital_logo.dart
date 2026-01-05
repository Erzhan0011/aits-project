import 'package:flutter/material.dart';
import 'dart:math' as math;

class OrbitalLogo extends StatefulWidget {
  final double size;
  const OrbitalLogo({super.key, this.size = 200});

  @override
  State<OrbitalLogo> createState() => _OrbitalLogoState();
}

class _OrbitalLogoState extends State<OrbitalLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Offset> _starPositions;
  late List<double> _starSizes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Pre-calculate star positions and sizes
    final random = math.Random(42);
    _starPositions = List.generate(40, (_) => Offset(
      random.nextDouble() * widget.size,
      random.nextDouble() * widget.size,
    ));
    _starSizes = List.generate(40, (_) => random.nextDouble() * 1.5);
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
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _OrbitalPainter(
                progress: _controller.value,
                starPositions: _starPositions,
                starSizes: _starSizes,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  final double progress;
  final List<Offset> starPositions;
  final List<double> starSizes;

  _OrbitalPainter({
    required this.progress,
    required this.starPositions,
    required this.starSizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.8;

    // --- 1. Draw Space & Stars ---
    final starPaint = Paint()..color = Colors.white;
    for (int i = 0; i < starPositions.length; i++) {
      final starPos = starPositions[i];
      final starSize = starSizes[i];
      double starOpacity = 0.3 + 0.7 * math.sin(progress * 2 * math.pi + i);
      // Ensure opacity is within valid range [0.0, 1.0]
      starOpacity = starOpacity.clamp(0.0, 1.0);
      starPaint.color = Colors.white.withOpacity(starSize > 1.2 ? starOpacity : 0.4);
      canvas.drawCircle(starPos, starSize, starPaint);
    }

    // --- 2. Calculate Plane Position (3D-ish Ellipse) ---
    // Increased eccentricity for better 3D feel
    final orbitWidth = size.width * 0.48;
    final orbitHeight = size.height * 0.15;
    final angle = progress * 2 * math.pi;
    
    // Z-index calculation (normalized -1 to 1)
    // When sin(angle) > 0, plane is in front. When < 0, it's behind.
    final zIndex = math.sin(angle);
    final px = center.dx + orbitWidth * math.cos(angle);
    final py = center.dy + orbitHeight * math.sin(angle) - (zIndex * 10); // Perspective shift

    // --- 3. Draw Orbit Path (Back Half) ---
    // (This part was removed or simplified to reduce overhead)
    
    // --- 4. Draw Planet (If Plane is Behind) ---
    if (zIndex < 0) {
      _drawPlane(canvas, px, py, angle, zIndex);
      _drawPlanet(canvas, center, radius);
    } else {
      _drawPlanet(canvas, center, radius);
      _drawPlane(canvas, px, py, angle, zIndex);
    }
  }

  void _drawPlanet(Canvas canvas, Offset center, double radius) {
    // Atmosphere Outer Glow
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, radius * 1.1, glowPaint);

    // Planet Body
    final planetPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, planetPaint);

    // Decorative "Continents" (Simple arcs/blobs)
    final landPaint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    // Simulate rotation of landmasses
    canvas.translate(math.sin(progress * 0.5 * math.pi) * 20, 0);
    canvas.drawCircle(center.translate(-15, -10), radius * 0.4, landPaint);
    canvas.drawCircle(center.translate(20, 15), radius * 0.3, landPaint);
    canvas.drawCircle(center.translate(10, -25), radius * 0.2, landPaint);
    canvas.restore();

    // Atmosphere Ring Highlight
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF38BDF8).withOpacity(0.4), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);
  }

  void _drawPlane(Canvas canvas, double px, double py, double angle, double zIndex) {
    final planeScale = 0.8 + (zIndex * 0.3); // Bigger when in front
    final rotationAngle = angle + math.pi / 2;

    canvas.save();
    canvas.translate(px, py);
    canvas.scale(planeScale);
    canvas.rotate(rotationAngle);

    // Plane Trail
    final trailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF38BDF8).withOpacity(0.6 * (1.0 - zIndex.abs() * 0.5)), Colors.transparent],
      ).createShader(const Rect.fromLTWH(-2, 5, 4, 25));
    canvas.drawRect(const Rect.fromLTWH(-1.5, 5, 3, 20), trailPaint);

    // Plane Body (Yellow/Gold)
    final planePaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0, -12) // nose
      ..lineTo(-10, 4) // left wing
      ..lineTo(-3, 1)  // fuselage
      ..lineTo(-3, 10) // tail left
      ..lineTo(0, 7)   // tail tip
      ..lineTo(3, 10)  // tail right
      ..lineTo(3, 1)   // fuselage
      ..lineTo(10, 4)  // right wing
      ..close();

    // Add depth shadow to plane
    canvas.drawPath(path, Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, planePaint);

    // Cockpit Window
    canvas.drawRect(const Rect.fromLTWH(-1.5, -8, 3, 2), Paint()..color = const Color(0xFF0F172A));

    // Engine Glow
    final glow = Paint()
      ..color = const Color(0xFF38BDF8)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * planeScale);
    canvas.drawCircle(const Offset(0, 6), 3, glow);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitalPainter oldDelegate) => true;
}
