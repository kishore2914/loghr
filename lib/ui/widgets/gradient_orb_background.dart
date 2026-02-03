import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:loghr_mobile/ui/theme/vibrant_colors.dart';

class GradientOrbBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? orbColors;

  const GradientOrbBackground({
    super.key,
    required this.child,
    this.orbColors,
  });

  @override
  State<GradientOrbBackground> createState() => _GradientOrbBackgroundState();
}

class _GradientOrbBackgroundState extends State<GradientOrbBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<OrbData> _orbs = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Create animated orbs
    final colors = widget.orbColors ?? VibrantColors.orbColors;
    final random = math.Random();
    
    for (int i = 0; i < 4; i++) {
      _orbs.add(OrbData(
        color: colors[i % colors.length],
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: 100 + random.nextDouble() * 200,
        speed: 0.3 + random.nextDouble() * 0.4,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: VibrantColors.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          // Animated Orbs
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: OrbsPainter(
                  orbs: _orbs,
                  animationValue: _controller.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Content
          widget.child,
        ],
      ),
    );
  }
}

class OrbData {
  final Color color;
  final double x;
  final double y;
  final double size;
  final double speed;

  OrbData({
    required this.color,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

class OrbsPainter extends CustomPainter {
  final List<OrbData> orbs;
  final double animationValue;

  OrbsPainter({
    required this.orbs,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final offsetX = size.width * orb.x +
          math.sin(animationValue * 2 * math.pi * orb.speed) * 50;
      final offsetY = size.height * orb.y +
          math.cos(animationValue * 2 * math.pi * orb.speed) * 50;

      final paint = Paint()
        ..color = orb.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

      canvas.drawCircle(
        Offset(offsetX, offsetY),
        orb.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(OrbsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

