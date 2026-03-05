import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ViewDataScreen extends StatefulWidget {
  const ViewDataScreen({super.key});

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
      child: AnimatedBuilder(
        animation: _enter,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_enter.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 10),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Devotee Reports',
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
              child: ListView(
                children: const [
                  _MetricCard(
                    title: 'Today Devotees',
                    value: '1,284',
                    icon: Icons.today_rounded,
                  ),
                  SizedBox(height: 12),
                  _MetricCard(
                    title: 'Weekly Count',
                    value: '8,942',
                    icon: Icons.date_range_rounded,
                  ),
                  SizedBox(height: 12),
                  _MetricCard(
                    title: 'Monthly Count',
                    value: '36,510',
                    icon: Icons.calendar_month_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.68),
                const Color(0xFFFFF8E7).withOpacity(0.36),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFD27D).withOpacity(0.40),
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFE9A8),
                        Color(0xFFFFB300),
                        Color(0xFFFF8F00),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD27D).withOpacity(0.26),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.templeBrown,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
