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
      '✨ May Lord Venkateswara Grace Your Seva Today',
      '🌸 Serving Every Devotee with Devotion and Precision',
      '🛕 Sacred Temple Administration Dashboard',
    ],
    [
      '🙏 Welcome, Admin',
      '✨ May Divine Light Guide Each Decision in Calmness',
      '🌸 Service is Worship — Technology is Our Sacred Lamp',
      '🛕 Sacred Temple Administration Dashboard',
    ],
    [
      '🙏 Welcome, Admin',
      '✨ May the Temple’s Presence Fill This Space with Peace',
      '🌸 Protecting and Guiding Devotees with Grace and Care',
      '🛕 Sacred Temple Administration Dashboard',
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
    return Scaffold(
      body: TempleImmersiveBackground(
        backgroundAsset: null,
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
  static const int _cardCount = 10;

  late final PageController _carousel;
  Timer? _autoScroll;

  late final AnimationController _enter;
  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  late final AnimationController _pulse;

  int _tapIndex = -1;

  @override
  void initState() {
    super.initState();

    _carousel = PageController(viewportFraction: 0.78);
    _carousel.addListener(_onCarousel);

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
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _carousel
      ..removeListener(_onCarousel)
      ..dispose();
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onCarousel() {
    if (!mounted) return;
    setState(() {});
  }

  void _startAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (!mounted) return;
      if (!_carousel.hasClients) return;

      final current = (_carousel.page ?? _carousel.initialPage.toDouble()).round();
      final next = current + 1;
      _carousel.animateToPage(
        next,
        duration: const Duration(milliseconds: 760),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onCardTap(int index) {
    setState(() => _tapIndex = index);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_tapIndex == index) setState(() => _tapIndex = -1);
    });
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
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_carousel, _pulse]),
                            builder: (context, _) {
                              final page = _carousel.hasClients
                                  ? (_carousel.page ?? _carousel.initialPage.toDouble())
                                  : 0.0;

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: RadialGradient(
                                            center: Alignment.center,
                                            radius: 0.85,
                                            colors: [
                                              const Color(0xFFFFD27D).withOpacity(
                                                0.10 +
                                                    0.10 *
                                                        (1 - (page - page.round()).abs()).clamp(0.0, 1.0),
                                              ),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  PageView.builder(
                                    controller: _carousel,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _cardCount,
                                    itemBuilder: (context, index) {
                                      final delta = (page - index).clamp(-3.0, 3.0);
                                      final dist = delta.abs().clamp(0.0, 1.0);

                                      final focus = (1 - dist);
                                      final scale = 0.88 + focus * 0.14;
                                      final opacity = 0.55 + focus * 0.45;
                                      final blurSigma = (1 - focus) * 6.0;

                                      final parallax = -delta * 14.0;
                                      final isCenter = dist < 0.001;
                                      final pulseT = Curves.easeOutCubic.transform(_pulse.value);
                                      final pulse = isCenter ? (1.0 + (1 - pulseT) * 0.02) : 1.0;

                                      final tapped = _tapIndex == index;
                                      final tapScale = tapped ? 1.03 : 1.0;

                                      return Center(
                                        child: Opacity(
                                          opacity: opacity,
                                          child: Transform.translate(
                                            offset: Offset(parallax, 0),
                                            child: Transform.scale(
                                              scale: scale * pulse * tapScale,
                                              child: ImageFiltered(
                                                imageFilter: ImageFilter.blur(
                                                  sigmaX: blurSigma,
                                                  sigmaY: blurSigma,
                                                ),
                                                child: _TempleCarouselCard(
                                                  label: 'Temple Image',
                                                  focused: isCenter,
                                                  onTap: () => _onCardTap(index),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
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

class _TempleCarouselCard extends StatelessWidget {
  const _TempleCarouselCard({
    required this.label,
    required this.focused,
    required this.onTap,
  });

  final String label;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = const Color(0xFFFFD27D);
    final bg = const Color(0xFFFFF8E7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: bg.withOpacity(0.34),
        border: Border.all(
          color: border.withOpacity(focused ? 0.92 : 0.52),
          width: focused ? 1.7 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
          if (focused)
            BoxShadow(
              color: border.withOpacity(0.40),
              blurRadius: 34,
              spreadRadius: 1.2,
              offset: const Offset(0, 16),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: border.withOpacity(0.20),
            highlightColor: border.withOpacity(0.08),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 62,
                      width: 62,
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
                            color: border.withOpacity(focused ? 0.38 : 0.22),
                            blurRadius: focused ? 28 : 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.templeBrown.withOpacity(0.88),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Opacity(
                      opacity: 0.74,
                      child: Text(
                        'Placeholder',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.templeBrown,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreetingOverlay extends StatelessWidget {
  const _GreetingOverlay({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          height: 1.25,
          shadows: [
            Shadow(color: const Color(0xFFFFD27D).withOpacity(0.55), blurRadius: 18),
            Shadow(color: Colors.black.withOpacity(0.65), blurRadius: 16),
          ],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines) ...[
          Text(line, style: textStyle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
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
                Icon(data.icon, color: color),
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
