import 'dart:math' as math;

import 'dart:ui';

import 'package:flutter/material.dart';

class DivineBackground extends StatefulWidget {
  const DivineBackground({super.key, required this.child});

  final Widget child;

  @override
  State<DivineBackground> createState() => _DivineBackgroundState();
}

class _DivineBackgroundState extends State<DivineBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  final math.Random _random = math.Random(42);
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _particles = List.generate(34, (i) {
      return _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 0.6 + _random.nextDouble() * 1.8,
        speed: 0.015 + _random.nextDouble() * 0.045,
        twinkle: _random.nextDouble() * 0.8,
        phase: _random.nextDouble() * math.pi * 2,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF8E7),
                  Color(0xFFFFFDF6),
                  Color(0xFFFFE8B6),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.9),
                  radius: 1.25,
                  colors: [
                    const Color(0xFFFFD27D).withOpacity(0.35),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -size.width * 0.26,
          left: -size.width * 0.24,
          child: _Mandala(
            diameter: size.width * 0.80,
            opacity: 0.045,
          ),
        ),
        Positioned(
          bottom: -size.width * 0.34,
          right: -size.width * 0.22,
          child: _Mandala(
            diameter: size.width * 0.86,
            opacity: 0.040,
          ),
        ),
        Positioned(
          top: size.height * 0.20,
          right: size.width * 0.08,
          child: _TempleBell(
            size: size.width * 0.18,
            opacity: 0.035,
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    t: _controller.value,
                    particles: _particles,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.twinkle,
    required this.phase,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double twinkle;
  final double phase;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.t, required this.particles});

  final double t;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = const Color(0xFFFFD27D);

    for (final p in particles) {
      final dy = (p.y - (t * p.speed)) % 1.0;
      final dx = (p.x + math.sin((t * 2 * math.pi) + p.phase) * 0.01) % 1.0;

      final alpha = (0.12 +
              (math.sin((t * 2 * math.pi) + p.phase) * 0.5 + 0.5) *
                  0.20 *
                  p.twinkle)
          .clamp(0.0, 0.28);

      final offset = Offset(dx * size.width, dy * size.height);
      final r = p.radius * (size.shortestSide / 420.0).clamp(0.9, 2.1);

      final glowPaint = Paint()
        ..color = baseColor.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(offset, r * 1.9, glowPaint);

      final corePaint = Paint()..color = Colors.white.withOpacity(alpha * 0.85);
      canvas.drawCircle(offset, r * 0.7, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.particles != particles;
  }
}

class _Mandala extends StatelessWidget {
  const _Mandala({required this.diameter, required this.opacity});

  final double diameter;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        size: Size.square(diameter),
        painter: _MandalaPainter(color: const Color(0xFFFFA000)),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final basePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.012
      ..strokeCap = StrokeCap.round;

    final ringCount = 5;
    for (var i = 1; i <= ringCount; i++) {
      final r = radius * (i / (ringCount + 1));
      canvas.drawCircle(center, r, basePaint..strokeWidth = radius * 0.008);
    }

    final petals = 24;
    final petalPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.008;

    for (var i = 0; i < petals; i++) {
      final angle = (2 * math.pi / petals) * i;
      final a = Offset(center.dx + math.cos(angle) * radius * 0.25,
          center.dy + math.sin(angle) * radius * 0.25);
      final b = Offset(center.dx + math.cos(angle) * radius * 0.95,
          center.dy + math.sin(angle) * radius * 0.95);
      canvas.drawLine(a, b, petalPaint);

      final arcRect = Rect.fromCircle(center: center, radius: radius * 0.55);
      canvas.drawArc(
        arcRect,
        angle - (math.pi / petals),
        (2 * math.pi / petals) * 0.6,
        false,
        petalPaint,
      );
    }

    final dotPaint = Paint()..color = color;
    final dotCount = 36;
    for (var i = 0; i < dotCount; i++) {
      final angle = (2 * math.pi / dotCount) * i;
      final p = Offset(center.dx + math.cos(angle) * radius * 0.72,
          center.dy + math.sin(angle) * radius * 0.72);
      canvas.drawCircle(p, radius * 0.01, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TempleBell extends StatelessWidget {
  const _TempleBell({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(
        Icons.notifications_active_rounded,
        size: size,
        color: const Color(0xFF4E342E),
      ),
    );
  }
}
