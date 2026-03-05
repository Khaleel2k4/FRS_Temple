import 'package:flutter/material.dart';

class GoldenGradientButton extends StatefulWidget {
  const GoldenGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  State<GoldenGradientButton> createState() => _GoldenGradientButtonState();
}

class _GoldenGradientButtonState extends State<GoldenGradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _shimmer,
        builder: (context, _) {
          final t = _shimmer.value;

          final baseGradient = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: disabled
                ? [
                    const Color(0xFFBDBDBD),
                    const Color(0xFF9E9E9E),
                  ]
                : [
                    const Color(0xFFFFE9A8),
                    const Color(0xFFFFB300),
                    const Color(0xFFFF8F00),
                  ],
          );

          return AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: baseGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_pressed ? 0.10 : 0.14),
                  blurRadius: _pressed ? 14 : 18,
                  offset: Offset(0, _pressed ? 6 : 8),
                ),
                if (!disabled)
                  BoxShadow(
                    color: const Color(0xFFFFD27D)
                        .withOpacity(_pressed ? 0.42 : 0.22),
                    blurRadius: _pressed ? 26 : 18,
                    spreadRadius: _pressed ? 1.5 : 0.2,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: disabled ? 0 : 0.65,
                        child: Transform.translate(
                          offset: Offset((t * 2 - 1) * 220, 0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.38),
                                  Colors.white.withOpacity(0.0),
                                ],
                                stops: const [0.35, 0.5, 0.65],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onPressed,
                      onTapDown: disabled
                          ? null
                          : (_) => setState(() => _pressed = true),
                      onTapCancel:
                          disabled ? null : () => setState(() => _pressed = false),
                      onTapUp: disabled
                          ? null
                          : (_) => setState(() => _pressed = false),
                      child: Center(
                        child: Text(
                          widget.label,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
