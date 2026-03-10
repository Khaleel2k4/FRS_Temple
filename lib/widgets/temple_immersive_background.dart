import 'dart:math' as math;

import 'dart:ui';

import 'package:flutter/material.dart';

class TempleImmersiveBackground extends StatefulWidget {
  const TempleImmersiveBackground({
    super.key,
    required this.child,
    this.backgroundAsset,
    this.topLeftDecorationAsset,
    this.topRightDecorationAsset,
    this.showParticles = true,
    this.showPetals = true,
  });

  final Widget child;
  final String? backgroundAsset;
  final String? topLeftDecorationAsset;
  final String? topRightDecorationAsset;
  final bool showParticles;
  final bool showPetals;

  @override
  State<TempleImmersiveBackground> createState() =>
      _TempleImmersiveBackgroundState();
}

class _TempleImmersiveBackgroundState extends State<TempleImmersiveBackground>
    with TickerProviderStateMixin {
  late final AnimationController _particles;
  late final AnimationController _petals;

  final math.Random _random = math.Random(7);
  late final List<_Particle> _particleList;
  late final List<_Petal> _petalList;

  @override
  void initState() {
    super.initState();

    _particles = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    _petals = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _particleList = List.generate(26, (i) {
      return _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        radius: 0.7 + _random.nextDouble() * 1.6,
        speed: 0.004 + _random.nextDouble() * 0.010,
        twinkle: 0.4 + _random.nextDouble() * 0.6,
        phase: _random.nextDouble() * math.pi * 2,
      );
    });

    _petalList = List.generate(18, (i) {
      return _Petal(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 10 + _random.nextDouble() * 18,
        drift: (_random.nextDouble() * 2 - 1) * 0.08,
        speed: 0.08 + _random.nextDouble() * 0.22,
        rotation: _random.nextDouble() * math.pi * 2,
        rotSpeed: (_random.nextDouble() * 2 - 1) * 0.6,
      );
    });
  }

  @override
  void dispose() {
    _particles.dispose();
    _petals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: widget.backgroundAsset == null
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFF8E7),
                        Color(0xFFF3E6CF),
                        Color(0xFFFFE0B2),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                )
              : Image.asset(
                  widget.backgroundAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFFF8E7).withOpacity(0.10),
                    const Color(0xFFFFE0B2).withOpacity(0.22),
                    const Color(0xFFFFB300).withOpacity(0.12),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.88),
                  radius: 1.15,
                  colors: [
                    const Color(0xFFFFD27D).withOpacity(0.26),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: _CornerDecoration(asset: widget.topLeftDecorationAsset),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _CornerDecoration(
            asset: widget.topRightDecorationAsset,
            flipX: true,
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _particles,
              builder: (context, _) {
                if (!widget.showParticles) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _SacredParticlePainter(
                    t: _particles.value,
                    particles: _particleList,
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _petals,
              builder: (context, _) {
                if (!widget.showPetals) return const SizedBox.shrink();
                return CustomPaint(
                  painter: _PetalPainter(
                    t: _petals.value,
                    petals: _petalList,
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

class _CornerDecoration extends StatelessWidget {
  const _CornerDecoration({this.asset, this.flipX = false});

  final String? asset;
  final bool flipX;

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      return const SizedBox.shrink();
    }

    final width = (MediaQuery.sizeOf(context).width * 0.26).clamp(120.0, 220.0);

    final child = Opacity(
      opacity: 0.85,
      child: Image.asset(
        asset!,
        width: width,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      ),
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(flipX ? -1.0 : 1.0, 1.0),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
        child: child,
      ),
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

class _SacredParticlePainter extends CustomPainter {
  _SacredParticlePainter({required this.t, required this.particles});

  final double t;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final base = const Color(0xFFFFD27D);

    for (final p in particles) {
      final dy = (p.y - (t * p.speed)) % 1.0;
      final dx = (p.x + math.sin((t * 2 * math.pi) + p.phase) * 0.008) % 1.0;

      final alpha = (0.08 +
              (math.sin((t * 2 * math.pi) + p.phase) * 0.5 + 0.5) *
                  0.16 *
                  p.twinkle)
          .clamp(0.0, 0.22);

      final o = Offset(dx * size.width, dy * size.height);
      final r = p.radius * (size.shortestSide / 520.0).clamp(0.8, 1.9);

      final glowPaint = Paint()
        ..color = base.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(o, r * 2.1, glowPaint);

      final corePaint = Paint()..color = Colors.white.withOpacity(alpha * 0.7);
      canvas.drawCircle(o, r * 0.7, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SacredParticlePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.particles != particles;
  }
}

class _Petal {
  _Petal({
    required this.x,
    required this.y,
    required this.size,
    required this.drift,
    required this.speed,
    required this.rotation,
    required this.rotSpeed,
  });

  final double x;
  final double y;
  final double size;
  final double drift;
  final double speed;
  final double rotation;
  final double rotSpeed;
}

class _PetalPainter extends CustomPainter {
  _PetalPainter({required this.t, required this.petals});

  final double t;
  final List<_Petal> petals;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      final fall = (p.y + t * p.speed) % 1.0;
      final fade = ((1.0 - fall) * 1.2).clamp(0.0, 1.0);
      final alpha = (0.51 * fade).clamp(0.0, 0.40);

      if (alpha <= 0.01) continue;

      final dx = (p.x + math.sin((t * 2 * math.pi) + p.rotation) * p.drift) % 1.0;
      final o = Offset(dx * size.width, fall * size.height);

      final angle = p.rotation + t * p.rotSpeed;

      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(angle);

      final w = p.size;
      final h = p.size * 1.25;

      final petalPath = Path()
        ..moveTo(0, -h * 0.45)
        ..quadraticBezierTo(w * 0.42, -h * 0.10, 0, h * 0.50)
        ..quadraticBezierTo(-w * 0.42, -h * 0.10, 0, -h * 0.45)
        ..close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFC1D6).withOpacity(alpha),
            const Color(0xFFF48FB1).withOpacity(alpha * 0.95),
          ],
        ).createShader(Rect.fromLTWH(-w, -h, w * 2, h * 2))
        ..style = PaintingStyle.fill;

      final glowPaint = Paint()
        ..color = const Color(0xFFFFD27D).withOpacity(alpha * 0.56)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25;

      canvas.drawPath(petalPath, glowPaint);
      canvas.drawPath(petalPath, fillPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.petals != petals;
  }
}
