import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    this.cameras,
    this.simulateDetection = true,
    this.previewBuilder,
    this.detectedCount,
    this.isDetectedNow,
  });

  final List<CameraFeed>? cameras;
  final bool simulateDetection;
  final Widget Function(BuildContext context, CameraFeed feed)? previewBuilder;
  final int Function(CameraFeed feed)? detectedCount;
  final bool Function(CameraFeed feed)? isDetectedNow;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  static const List<CameraFeed> _defaultCameras = <CameraFeed>[
    CameraFeed(id: 'cam_1', label: 'Camera 1 – Temple Entrance', online: true),
    CameraFeed(id: 'cam_2', label: 'Camera 2 – Main Hall', online: true),
    CameraFeed(id: 'cam_3', label: 'Camera 3 – Queue Area', online: true),
    CameraFeed(id: 'cam_4', label: 'Camera 4 – Temple Gate', online: true),
    CameraFeed(id: 'cam_5', label: 'Camera 5 – Prasadam Counter', online: true),
    CameraFeed(id: 'cam_6', label: 'Camera 6 – Outer Corridor', online: false),
  ];

  late final AnimationController _scan;
  late final AnimationController _liveBlink;

  final math.Random _random = math.Random(11);
  Timer? _detectionTimer;

  int? _selectedIndex;

  late List<int> _detectedPerCamera;

  final Map<int, DateTime> _detectedUntil = <int, DateTime>{};

  List<CameraFeed> get _cameras {
    final incoming = widget.cameras;
    if (incoming == null || incoming.isEmpty) return _defaultCameras;
    return incoming;
  }

  void _syncDetectionState() {
    final needed = _cameras.length;
    if (_detectedPerCamera.length == needed) return;

    final next = List<int>.filled(needed, 0, growable: true);
    for (var i = 0; i < math.min(_detectedPerCamera.length, needed); i++) {
      next[i] = _detectedPerCamera[i];
    }
    _detectedPerCamera = next;
    _detectedUntil.removeWhere((k, _) => k >= needed);
    if (_selectedIndex != null && _selectedIndex! >= needed) {
      _selectedIndex = null;
    }
  }

  @override
  void initState() {
    super.initState();

    _detectedPerCamera = List<int>.filled(_cameras.length, 0, growable: true);

    _scan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _liveBlink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    if (widget.simulateDetection) {
      _startDetectionSimulation();
    }
  }

  @override
  void didUpdateWidget(covariant CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cameras != oldWidget.cameras) {
      setState(_syncDetectionState);
    }

    if (widget.simulateDetection != oldWidget.simulateDetection) {
      if (widget.simulateDetection) {
        _startDetectionSimulation();
      } else {
        _detectionTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _scan.dispose();
    _liveBlink.dispose();
    super.dispose();
  }

  void _startDetectionSimulation() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;

      final online = <int>[];
      for (var i = 0; i < _cameras.length; i++) {
        if (_cameras[i].online) online.add(i);
      }
      if (online.isEmpty) return;

      final idx = online[_random.nextInt(online.length)];
      final add = 1 + _random.nextInt(2);

      setState(() {
        _detectedPerCamera[idx] += add;
        _detectedUntil[idx] = DateTime.now().add(const Duration(seconds: 2));
      });
    });
  }

  bool _isDetectedNow(int index) {
    final feed = _cameras[index];
    final external = widget.isDetectedNow;
    if (external != null) return external(feed);

    final until = _detectedUntil[index];
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  int _detectedCount(int index) {
    final feed = _cameras[index];
    final external = widget.detectedCount;
    if (external != null) return external(feed);
    return _detectedPerCamera[index];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.96).clamp(320.0, 920.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: AnimatedBuilder(
            animation: Listenable.merge([_scan, _liveBlink]),
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBlock(scanT: _scan.value),
                  const SizedBox(height: 14),
                  if (_selectedIndex != null) ...[
                    _SelectedCameraView(
                      info: _cameras[_selectedIndex!],
                      detected: _detectedCount(_selectedIndex!),
                      scanT: _scan.value,
                      highlightT: _scan.value,
                      previewBuilder: widget.previewBuilder,
                      onClose: () => setState(() => _selectedIndex = null),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: _CameraGrid(
                      cameras: _cameras,
                      scanT: _scan.value,
                      liveBlinkT: _liveBlink.value,
                      detectedNow: _isDetectedNow,
                      previewBuilder: widget.previewBuilder,
                      onTapCamera: (i) {
                        setState(() => _selectedIndex = i);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class CameraFeed {
  const CameraFeed({
    required this.id,
    required this.label,
    required this.online,
  });

  final String id;
  final String label;
  final bool online;
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.scanT});

  final double scanT;

  @override
  Widget build(BuildContext context) {
    final glow = (0.25 + 0.10 * math.sin(scanT * math.pi * 2)).clamp(0.12, 0.34);

    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.2,
          shadows: [
            Shadow(color: const Color(0xFFFFD27D).withOpacity(glow), blurRadius: 22),
            Shadow(color: Colors.black.withOpacity(0.60), blurRadius: 16),
          ],
        );

    final subStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.86),
          letterSpacing: 0.15,
          shadows: [
            Shadow(color: Colors.black.withOpacity(0.45), blurRadius: 14),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📹 Temple Surveillance', style: titleStyle),
        const SizedBox(height: 6),
        Text('Monitoring Devotee Activity', style: subStyle),
      ],
    );
  }
}

class _SelectedCameraView extends StatelessWidget {
  const _SelectedCameraView({
    required this.info,
    required this.detected,
    required this.scanT,
    required this.highlightT,
    required this.previewBuilder,
    required this.onClose,
  });

  final CameraFeed info;
  final int detected;
  final double scanT;
  final double highlightT;
  final Widget Function(BuildContext context, CameraFeed feed)? previewBuilder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFFFD27D);
    final pulse = (0.5 + 0.5 * math.sin(highlightT * math.pi * 2)).clamp(0.0, 1.0);
    final borderOpacity = (0.55 + 0.30 * pulse).clamp(0.40, 0.92);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0B0E12).withOpacity(0.88),
            const Color(0xFF10141A).withOpacity(0.74),
          ],
        ),
        border: Border.all(color: border.withOpacity(borderOpacity), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.38),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: border.withOpacity(0.18 + 0.20 * pulse),
            blurRadius: 38,
            spreadRadius: 0.8,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.15,
                      ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0C0F).withOpacity(0.92),
                      ),
                      child: previewBuilder?.call(context, info) ??
                          _CctvPlaceholder(
                            scanT: scanT,
                            label: 'Live Camera Feed',
                            emphasize: true,
                          ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _MetricChip(
                      icon: Icons.person_rounded,
                      text: 'Detected Devotees: $detected',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFFFD27D);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            border: Border.all(color: border.withOpacity(0.40), width: 1.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: border.withOpacity(0.95)),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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

class _CameraGrid extends StatelessWidget {
  const _CameraGrid({
    required this.cameras,
    required this.scanT,
    required this.liveBlinkT,
    required this.detectedNow,
    required this.previewBuilder,
    required this.onTapCamera,
  });

  final List<CameraFeed> cameras;
  final double scanT;
  final double liveBlinkT;
  final bool Function(int index) detectedNow;
  final Widget Function(BuildContext context, CameraFeed feed)? previewBuilder;
  final ValueChanged<int> onTapCamera;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: cameras.length,
      itemBuilder: (context, index) {
        final info = cameras[index];
        final detected = detectedNow(index);
        return _CameraTile(
          info: info,
          scanT: scanT,
          liveBlinkT: liveBlinkT,
          detected: detected,
          previewBuilder: previewBuilder,
          onTap: () => onTapCamera(index),
        );
      },
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({
    required this.info,
    required this.scanT,
    required this.liveBlinkT,
    required this.detected,
    required this.previewBuilder,
    required this.onTap,
  });

  final CameraFeed info;
  final double scanT;
  final double liveBlinkT;
  final bool detected;
  final Widget Function(BuildContext context, CameraFeed feed)? previewBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFFFD27D);
    final liveAlpha = (0.30 + 0.70 * (0.5 + 0.5 * math.sin(liveBlinkT * math.pi * 2))).clamp(0.18, 1.0);
    final pulse = (0.5 + 0.5 * math.sin(scanT * math.pi * 2)).clamp(0.0, 1.0);
    final borderOpacity = detected ? (0.62 + 0.28 * pulse) : 0.22;
    final borderWidth = detected ? 1.6 : 1.1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0B0E12).withOpacity(0.84),
            const Color(0xFF10141A).withOpacity(0.70),
          ],
        ),
        border: Border.all(color: border.withOpacity(borderOpacity), width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.40),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
          if (detected)
            BoxShadow(
              color: border.withOpacity(0.20 + 0.22 * pulse),
              blurRadius: 28,
              spreadRadius: 0.8,
              offset: const Offset(0, 14),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: border.withOpacity(0.18),
            highlightColor: border.withOpacity(0.08),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0C0F).withOpacity(0.90),
                    ),
                    child: previewBuilder?.call(context, info) ??
                        _CctvPlaceholder(
                          scanT: scanT,
                          label: 'Live Camera Feed',
                        ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    info.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          shadows: [
                            Shadow(color: Colors.black.withOpacity(0.70), blurRadius: 12),
                          ],
                        ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: _StatusPill(
                    online: info.online,
                    liveAlpha: liveAlpha,
                  ),
                ),
                if (detected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _DetectedPill(pulse: pulse),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.online, required this.liveAlpha});

  final bool online;
  final double liveAlpha;

  @override
  Widget build(BuildContext context) {
    final dotColor = online ? Colors.redAccent : Colors.white70;
    final text = online ? 'LIVE' : 'OFFLINE';
    final dotOpacity = online ? liveAlpha : 0.85;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor.withOpacity(dotOpacity),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withOpacity(dotOpacity * 0.55),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.4,
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

class _DetectedPill extends StatelessWidget {
  const _DetectedPill({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFFFD27D);
    final glow = (0.25 + 0.25 * pulse).clamp(0.18, 0.55);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.28),
            border: Border.all(color: border.withOpacity(0.55 + 0.25 * pulse)),
            boxShadow: [
              BoxShadow(
                color: border.withOpacity(glow),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              '👤 Devotee Detected',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CctvPlaceholder extends StatelessWidget {
  const _CctvPlaceholder({required this.scanT, required this.label, this.emphasize = false});

  final double scanT;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _CctvNoisePainter(t: scanT, emphasize: emphasize),
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
                    Colors.transparent,
                    const Color(0xFFFFD27D).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_rounded, size: emphasize ? 58 : 40, color: Colors.white38),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.62),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(color: Colors.black.withOpacity(0.70), blurRadius: 12),
                      ],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CctvNoisePainter extends CustomPainter {
  _CctvNoisePainter({required this.t, required this.emphasize});

  final double t;
  final bool emphasize;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFF0E1116);
    canvas.drawRect(Offset.zero & size, base);

    final scanY = (t * size.height) % size.height;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(emphasize ? 0.09 : 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, scanY - 60, size.width, 120));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 60, size.width, 120), scanPaint);

    final linePaint = Paint()..color = Colors.white.withOpacity(emphasize ? 0.045 : 0.035);
    final step = emphasize ? 5.0 : 6.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), linePaint);
    }

    final noise = Paint()..color = Colors.white.withOpacity(emphasize ? 0.040 : 0.028);
    final count = emphasize ? 120 : 90;
    final seed = (t * 100000).floor();
    for (var i = 0; i < count; i++) {
      final x = _hash(seed + i * 17) * size.width;
      final y = _hash(seed + i * 31) * size.height;
      final w = 1.0 + _hash(seed + i * 47) * 2.6;
      canvas.drawRect(Rect.fromLTWH(x, y, w, 1.0), noise);
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.55),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  double _hash(int n) {
    final x = math.sin(n * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant _CctvNoisePainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.emphasize != emphasize;
  }
}
