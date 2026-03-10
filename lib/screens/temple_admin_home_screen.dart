import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/temple_immersive_background.dart';
import 'analysis_screen.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'view_data_screen.dart';

class TempleAdminHomeScreen extends StatefulWidget {
  const TempleAdminHomeScreen({super.key});

  @override
  State<TempleAdminHomeScreen> createState() => _TempleAdminHomeScreenState();
}

class _TempleAdminHomeScreenState extends State<TempleAdminHomeScreen>
    with TickerProviderStateMixin {
  static const Duration _welcomeDuration = Duration(milliseconds: 2800);

  static const List<List<String>> _greetingVariants = [
    [
      '🙏 Welcome, Admin',
      'Serving Devotees with Devotion',
    ],
    [
      '🙏 Welcome, Admin',
      'Serving Devotees with Devotion',
    ],
    [
      '🙏 Welcome, Admin',
      'Serving Devotees with Devotion',
    ],
  ];

  late final AnimationController _welcomeController;
  late final Animation<double> _omFadeIn;
  late final Animation<double> _omScale;
  late final Animation<double> _lightSpread;
  late final Animation<double> _contentReveal;

  late final AnimationController _greetingController;
  late final Animation<double> _greetingFade;
  late final Animation<double> _greetingFloat;

  late final List<String> _greetingLines;
  int _selectedTab = 0;

  bool _bellEnabled = true;

  @override
  void initState() {
    super.initState();

    _welcomeController = AnimationController(vsync: this, duration: _welcomeDuration);
    _omFadeIn = CurvedAnimation(
      parent: _welcomeController,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    );
    _omScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );
    _lightSpread = CurvedAnimation(
      parent: _welcomeController,
      curve: const Interval(0.26, 0.78, curve: Curves.easeInOutCubic),
    );
    _contentReveal = CurvedAnimation(
      parent: _welcomeController,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOutCubic),
    );

    _greetingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _greetingFade = CurvedAnimation(parent: _greetingController, curve: Curves.easeOutCubic);
    _greetingFloat = Tween<double>(begin: 8.0, end: 0.0).animate(
      CurvedAnimation(parent: _greetingController, curve: Curves.easeOutCubic),
    );

    _greetingLines = _greetingVariants[
        math.Random().nextInt(_greetingVariants.length) % _greetingVariants.length];

    _welcomeController.forward();
    Future<void>.delayed(const Duration(milliseconds: 880), () {
      if (mounted) _greetingController.forward();
    });

    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _playBellOnceIfEnabled();
    });
  }

  Future<void> _playBellOnceIfEnabled() async {
    if (!_bellEnabled) return;
    const soundAsset = 'assets/sounds/temple_bell.mp3';
    try {
      await rootBundle.load(soundAsset);
    } catch (_) {
      return;
    }

    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  @override
  void dispose() {
    _welcomeController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAmbientEffects = _selectedTab != 3;
    return Scaffold(
      body: TempleImmersiveBackground(
        backgroundAsset: null,
        showParticles: showAmbientEffects,
        showPetals: showAmbientEffects,
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _MandalaPatternOverlay()),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _welcomeController,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _contentReveal.value,
                      child: IndexedStack(
                        index: _selectedTab,
                        children: [
                          _HomeTab(
                            greetingFade: _greetingFade,
                            greetingFloat: _greetingFloat,
                            greetingLines: _greetingLines,
                          ),
                          const ViewDataScreen(),
                          const CameraScreen(),
                          const AnalysisScreen(),
                          SettingsScreen(
                            bellEnabled: _bellEnabled,
                            onBellEnabledChanged: (v) {
                              setState(() => _bellEnabled = v);
                            },
                            onLogout: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: _DivineTopBar(
                  adminName: 'Temple Admin',
                  onMenuSelected: (value) {
                    if (value == _AdminMenuItem.logout) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _welcomeController,
                    builder: (context, _) {
                      if (_welcomeController.isCompleted) {
                        return const SizedBox.shrink();
                      }
                      return _DivineWelcomeOverlay(
                        omOpacity: _omFadeIn.value,
                        omScale: _omScale.value,
                        lightSpread: _lightSpread.value,
                      );
                    },
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _DivineBottomNavBar(
                    selectedIndex: _selectedTab,
                    onSelected: (index) {
                      setState(() => _selectedTab = index);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AdminMenuItem { profile, notifications, logout }

class _DivineTopBar extends StatelessWidget {
  const _DivineTopBar({required this.adminName, required this.onMenuSelected});

  final String adminName;

  final ValueChanged<_AdminMenuItem> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF1C6),
              Color(0xFFFFD27D),
              Color(0xFFFFB300),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD27D).withOpacity(0.32),
              blurRadius: 26,
              spreadRadius: 0.5,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.38), width: 1.0),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: PopupMenuButton<_AdminMenuItem>(
                onSelected: onMenuSelected,
                itemBuilder: (context) {
                  return [
                    PopupMenuItem<_AdminMenuItem>(
                      enabled: false,
                      value: _AdminMenuItem.profile,
                      child: Text(
                        adminName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _AdminMenuItem.profile,
                      child: Text('Profile'),
                    ),
                    const PopupMenuItem(
                      value: _AdminMenuItem.notifications,
                      child: Text('Notifications'),
                    ),
                    const PopupMenuItem(
                      value: _AdminMenuItem.logout,
                      child: Text('Logout'),
                    ),
                  ];
                },
                child: Container(
                  height: 44,
                  width: 44,
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
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.0),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Temple Administration',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    letterSpacing: 0.2,
                    color: AppTheme.templeBrown,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 54),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.greetingFade,
    required this.greetingFloat,
    required this.greetingLines,
  });

  final Animation<double> greetingFade;
  final Animation<double> greetingFloat;
  final List<String> greetingLines;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  static const List<String> _templeImageAssets = <String>[
    'assets/images/Malekallu_Tirupathi-balaji,_Arsikere.jpg',
    'assets/images/img5.jpg',
    'assets/images/img7.jpg',
    'assets/images/temple_deity.png',
  ];

  late final AnimationController _enter;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _enterFade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _enterSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _enter.forward();
      _pulse.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final maxW = (size.width * 0.92).clamp(320.0, 720.0);
    final cardH = (size.height * 0.46).clamp(260.0, 460.0);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.02),
                  radius: 1.05,
                  colors: [
                    const Color(0xFFFFD27D).withOpacity(0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
          child: Column(
            children: [
              Center(
                child: FadeTransition(
                  opacity: widget.greetingFade,
                  child: AnimatedBuilder(
                    animation: widget.greetingFloat,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, widget.greetingFloat.value),
                        child: child,
                      );
                    },
                    child: _GreetingOverlay(lines: widget.greetingLines),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FadeTransition(
                  opacity: _enterFade,
                  child: SlideTransition(
                    position: _enterSlide,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxW),
                        child: SizedBox(
                          height: cardH,
                          child: _TempleImageShowcase(
                            imageAssets: _templeImageAssets,
                            pulse: _pulse,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TempleImageShowcase extends StatefulWidget {
  const _TempleImageShowcase({
    required this.imageAssets,
    required this.pulse,
  });

  final List<String> imageAssets;
  final AnimationController pulse;

  @override
  State<_TempleImageShowcase> createState() => _TempleImageShowcaseState();
}

class _TempleImageShowcaseState extends State<_TempleImageShowcase>
    with TickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(seconds: 10);
  static const Duration _autoAdvanceEvery = Duration(seconds: 10);

  late final AnimationController _transition;

  Timer? _autoAdvance;

  int _index = 0;
  bool _busy = false;
  int _direction = 1;

  final Map<String, double> _aspectRatioCache = <String, double>{};

  @override
  void initState() {
    super.initState();
    _transition = AnimationController(vsync: this, duration: _transitionDuration);

    _startOrResetAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvance?.cancel();
    _transition.dispose();
    super.dispose();
  }

  int _wrap(int i) {
    final n = widget.imageAssets.length;
    if (n == 0) return 0;
    return (i % n + n) % n;
  }

  void _startOrResetAutoAdvance() {
    _autoAdvance?.cancel();
    _autoAdvance = Timer.periodic(_autoAdvanceEvery, (_) {
      if (!mounted) return;
      _next();
    });
  }

  Future<double?> _resolveAspectRatio(String asset) async {
    final cached = _aspectRatioCache[asset];
    if (cached != null) return cached;

    final completer = Completer<ImageInfo>();
    final stream = AssetImage(asset).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info);
        stream.removeListener(listener);
      },
      onError: (_, __) {
        if (!completer.isCompleted) completer.completeError('error');
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);

    try {
      final info = await completer.future;
      final ratio = info.image.width / info.image.height;
      _aspectRatioCache[asset] = ratio;
      return ratio;
    } catch (_) {
      return null;
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    if (widget.imageAssets.isEmpty) return;

    setState(() => _busy = true);
    _direction = 1;
    _startOrResetAutoAdvance();
    await _transition.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _index = _wrap(_index + 1);
      _busy = false;
    });
    widget.pulse.forward(from: 0);
  }

  Future<void> _previous() async {
    if (_busy) return;
    if (widget.imageAssets.isEmpty) return;

    setState(() => _busy = true);
    _direction = -1;
    _startOrResetAutoAdvance();
    await _transition.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _index = _wrap(_index - 1);
      _busy = false;
    });
    widget.pulse.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImages = widget.imageAssets.isNotEmpty;

    final frontAsset = hasImages ? widget.imageAssets[_wrap(_index)] : null;
    final midAsset = hasImages ? widget.imageAssets[_wrap(_index + 1)] : null;
    final backAsset = hasImages ? widget.imageAssets[_wrap(_index + 2)] : null;

    return AnimatedBuilder(
      animation: Listenable.merge([_transition, widget.pulse]),
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_transition.value);
        final pulseT = Curves.easeOutCubic.transform(widget.pulse.value);
        final pulse = 1.0 + (1 - pulseT) * 0.015;

        final dir = _direction.toDouble().clamp(-1.0, 1.0);

        final frontX = lerpDouble(0, -74 * dir, t) ?? 0;
        final frontY = lerpDouble(0, -18, t) ?? 0;
        final frontScale = lerpDouble(1.0, 0.94, t) ?? 1.0;
        final frontOpacity = lerpDouble(1.0, 0.0, t) ?? 1.0;
        final frontShadow = lerpDouble(1.0, 0.0, t) ?? 1.0;

        final midX = lerpDouble(14 * dir, 0, t) ?? 0;
        final midY = lerpDouble(18, 0, t) ?? 0;
        final midScale = lerpDouble(0.92, 1.0, t) ?? 1.0;
        final midRot = lerpDouble(-0.03, 0.0, t) ?? 0.0;
        final midShadow = lerpDouble(0.75, 1.0, t) ?? 1.0;

        final backX = lerpDouble(26 * dir, 14 * dir, t) ?? 0;
        final backY = lerpDouble(32, 18, t) ?? 0;
        final backScale = lerpDouble(0.86, 0.92, t) ?? 1.0;
        final backRot = lerpDouble(0.04, -0.03, t) ?? 0.0;
        final backOpacity = lerpDouble(0.70, 0.86, t) ?? 1.0;
        final backShadow = lerpDouble(0.45, 0.75, t) ?? 1.0;

        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.10),
                      radius: 0.95,
                      colors: [
                        const Color(0xFFFFD27D).withOpacity(0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            _StackCard(
              opacity: backOpacity,
              translateX: backX,
              translateY: backY,
              scale: backScale,
              rotation: backRot,
              shadowStrength: backShadow,
              child: _DivineImageCard(
                label: 'Temple Image',
                asset: backAsset,
                resolveAspectRatio: _resolveAspectRatio,
                tint: cs.surface,
              ),
            ),
            _StackCard(
              opacity: 0.92,
              translateX: midX,
              translateY: midY,
              scale: midScale,
              rotation: midRot,
              shadowStrength: midShadow,
              child: _DivineImageCard(
                label: 'Temple Image',
                asset: midAsset,
                resolveAspectRatio: _resolveAspectRatio,
                tint: cs.surface,
              ),
            ),
            _StackCard(
              opacity: frontOpacity,
              translateX: frontX,
              translateY: frontY,
              scale: frontScale * pulse,
              rotation: 0.0,
              shadowStrength: frontShadow,
              child: GestureDetector(
                onTap: _next,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! < -60) {
                    _next();
                  } else if (details.primaryVelocity! > 60) {
                    _previous();
                  }
                },
                child: _DivineImageCard(
                  label: 'Temple Image',
                  asset: frontAsset,
                  resolveAspectRatio: _resolveAspectRatio,
                  tint: cs.surface,
                  emphasize: true,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StackCard extends StatelessWidget {
  const _StackCard({
    required this.child,
    required this.opacity,
    this.translateX = 0,
    required this.translateY,
    required this.scale,
    required this.rotation,
    required this.shadowStrength,
  });

  final Widget child;
  final double opacity;
  final double translateX;
  final double translateY;
  final double scale;
  final double rotation;
  final double shadowStrength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: opacity < 0.95,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(translateX, translateY),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: _ShadowStrength(
                strength: shadowStrength,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShadowStrength extends InheritedWidget {
  const _ShadowStrength({required this.strength, required super.child});

  final double strength;

  static double of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShadowStrength>()?.strength ??
        1.0;
  }

  @override
  bool updateShouldNotify(covariant _ShadowStrength oldWidget) {
    return oldWidget.strength != strength;
  }
}

class _DivineImageCard extends StatelessWidget {
  const _DivineImageCard({
    required this.label,
    required this.asset,
    required this.resolveAspectRatio,
    required this.tint,
    this.emphasize = false,
  });

  final String label;
  final String? asset;
  final Future<double?> Function(String asset) resolveAspectRatio;
  final Color tint;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final strength = _ShadowStrength.of(context);
    const border = Color(0xFFFFD27D);
    const bg = Color(0xFFFFF8E7);

    final outerShadowOpacity = (0.18 * strength).clamp(0.06, 0.22);
    final goldShadowOpacity = (0.40 * strength).clamp(0.10, 0.46);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: bg.withOpacity(0.78),
        border: Border.all(
          color: border.withOpacity(emphasize ? 0.92 : 0.62),
          width: emphasize ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(outerShadowOpacity),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: border.withOpacity(goldShadowOpacity),
            blurRadius: emphasize ? 44 : 34,
            spreadRadius: emphasize ? 1.2 : 0.6,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.45),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: asset == null
                        ? const _TempleImagePlaceholder()
                        : FutureBuilder<double?>(
                            future: resolveAspectRatio(asset!),
                            builder: (context, snapshot) {
                              final ratio = snapshot.data;
                              final ar = (ratio == null || ratio.isNaN || ratio <= 0)
                                  ? 3 / 4
                                  : ratio;

                              return Center(
                                child: AspectRatio(
                                  aspectRatio: ar,
                                  child: Image.asset(
                                    asset!,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (context, _, __) {
                                      return const _TempleImagePlaceholder();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: AppTheme.templeBrown.withOpacity(0.86),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TempleImagePlaceholder extends StatelessWidget {
  const _TempleImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
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
                  color: const Color(0xFFFFD27D).withOpacity(0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.0),
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Temple Image Placeholder',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.templeBrown.withOpacity(0.82),
                ),
          ),
        ],
      ),
    );
  }
}

class _GreetingOverlay extends StatelessWidget {
  const _GreetingOverlay({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final headline = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          height: 1.10,
          shadows: [
            Shadow(color: const Color(0xFFFFD27D).withOpacity(0.60), blurRadius: 22),
            Shadow(color: Colors.black.withOpacity(0.55), blurRadius: 16),
          ],
        );

    final sub = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white.withOpacity(0.92),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
          height: 1.18,
          shadows: [
            Shadow(color: const Color(0xFFFFD27D).withOpacity(0.45), blurRadius: 18),
            Shadow(color: Colors.black.withOpacity(0.45), blurRadius: 14),
          ],
        );

    final l0 = lines.isNotEmpty ? lines.first : '';
    final l1 = lines.length > 1 ? lines[1] : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l0, style: headline, textAlign: TextAlign.center),
        if (l1.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(l1, style: sub, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _DivineBottomNavBar extends StatelessWidget {
  const _DivineBottomNavBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = <_NavItemData>[
      _NavItemData(label: 'Home', icon: Icons.home_rounded),
      _NavItemData(label: 'View Data', icon: Icons.people_alt_rounded),
      _NavItemData(label: 'Camera', icon: Icons.camera_alt_rounded),
      _NavItemData(label: 'Analysis', icon: Icons.analytics_rounded),
      _NavItemData(label: 'Settings', icon: Icons.settings_rounded),
    ];

    return Container(
      height: 78,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.84),
            const Color(0xFFFFF8E7).withOpacity(0.82),
          ],
        ),
        border: Border.all(color: const Color(0xFFFFD27D).withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFFFFD27D).withOpacity(0.24),
            blurRadius: 30,
            spreadRadius: 0.6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final tabW = w / items.length;
          final indicatorLeft = tabW * selectedIndex;

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                left: indicatorLeft,
                top: 8,
                bottom: 8,
                width: tabW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
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
                          color: const Color(0xFFFFD27D).withOpacity(0.45),
                          blurRadius: 22,
                          spreadRadius: 0.2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavItem(
                        data: items[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppTheme.templeBrown.withOpacity(0.78);
    final glow = const Color(0xFFFFD27D);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            scale: selected ? 1.06 : 1.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: glow.withOpacity(0.55),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : const [],
                  ),
                  child: Icon(data.icon, color: color),
                ),
                const SizedBox(height: 6),
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.1,
                    shadows: selected
                        ? [
                            Shadow(
                              color: glow.withOpacity(0.50),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
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

class _DivineWelcomeOverlay extends StatelessWidget {
  const _DivineWelcomeOverlay({
    required this.omOpacity,
    required this.omScale,
    required this.lightSpread,
  });

  final double omOpacity;
  final double omScale;
  final double lightSpread;

  @override
  Widget build(BuildContext context) {
    final spread = Curves.easeInOutCubic.transform(lightSpread);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.35 + spread * 1.35,
                colors: [
                  const Color(0xFFFFD27D).withOpacity(0.16 + spread * 0.20),
                  const Color(0xFFFFF8E7).withOpacity(0.12 + spread * 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
        ),
        Center(
          child: Transform.scale(
            scale: omScale,
            child: Opacity(
              opacity: omOpacity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD27D).withOpacity(0.32),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                  Text(
                    'ॐ',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFD27D).withOpacity(0.98),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFFD27D).withOpacity(0.75),
                          blurRadius: 34,
                        ),
                        Shadow(
                          color: Colors.white.withOpacity(0.50),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MandalaPatternOverlay extends StatelessWidget {
  const _MandalaPatternOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _MandalaPainter(seed: 7),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final base = AppTheme.templeBrown.withOpacity(0.06);
    final gold = AppTheme.richGold.withOpacity(0.05);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.5, size.height * 0.24);
    final maxR = math.min(size.width, size.height) * 0.56;

    for (var i = 0; i < 8; i++) {
      final t = i / 7.0;
      final r = (0.18 + t * 0.82) * maxR;
      paint.color = Color.lerp(base, gold, t) ?? base;
      canvas.drawCircle(center, r, paint);
    }

    paint.color = gold.withOpacity(0.06);
    final petals = 16;
    final petalR = maxR * 0.76;
    for (var i = 0; i < petals; i++) {
      final a = (i / petals) * math.pi * 2;
      final p = center + Offset(math.cos(a), math.sin(a)) * petalR;
      canvas.drawCircle(p, maxR * 0.10, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.70),
                  const Color(0xFFFFF8E7).withOpacity(0.42),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFD27D).withOpacity(0.38), width: 1.0),
            ),
            child: Center(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
