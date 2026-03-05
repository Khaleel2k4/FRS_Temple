import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chart;

  @override
  void initState() {
    super.initState();
    _chart = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _chart.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 16,
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.70),
                        const Color(0xFFFFF8E7).withOpacity(0.38),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD27D).withOpacity(0.42),
                      width: 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedBuilder(
                      animation: _chart,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _BarChartPainter(
                            t: Curves.easeOutCubic.transform(_chart.value),
                          ),
                          child: const SizedBox.expand(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  _BarChartPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = [0.35, 0.62, 0.48, 0.76, 0.58, 0.88, 0.66];
    final basePaint = Paint()
      ..color = AppTheme.sandalwood.withOpacity(0.35)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), basePaint);
    }

    final gap = 10.0;
    final barW = (size.width - gap * (bars.length - 1)) / bars.length;

    for (var i = 0; i < bars.length; i++) {
      final h = (size.height * 0.80) * bars[i] * t;
      final x = i * (barW + gap);
      final r = Rect.fromLTWH(x, size.height - h, barW, h);

      final barPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFE9A8),
            Color(0xFFFFB300),
            Color(0xFFFF8F00),
          ],
        ).createShader(r);

      final rr = RRect.fromRectAndRadius(r, const Radius.circular(10));
      canvas.drawRRect(rr, barPaint);

      final glow = Paint()
        ..color = const Color(0xFFFFD27D).withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      canvas.drawRRect(rr, glow);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
