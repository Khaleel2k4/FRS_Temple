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
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFFFFD27D).withOpacity(0.24),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.templeBrown,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Temple Administration',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.2,
                      color: AppTheme.templeBrown,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_AdminMenuItem>(
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
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
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
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
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

  static const List<String> _devotionalQuotes = <String>[
    'Serving Devotees with Devotion 🙏',
    'Where Faith Meets Peace',
    'Divine Energy Flows Here',
    'Experience Spiritual Bliss',
    'Temple of Faith and Hope',
  ];

  late final PageController _pageController;
  late final AnimationController _autoScrollController;
  late final AnimationController _fadeController;
  late final AnimationController _gridStagger;

  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _autoScrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _gridStagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeController.forward();
    _startAutoScroll();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _gridStagger.forward();
    });
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _nextPage();
    });
  }

  void _nextPage() {
    if (_currentPage < _templeImageAssets.length - 1) {
      _currentPage++;
    } else {
      _currentPage = 0;
    }
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _autoScrollController.dispose();
    _fadeController.dispose();
    _gridStagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF1C6),
            Color(0xFFFFF8E7),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
        child: Column(
          children: [
            FadeTransition(
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
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _fadeController,
              child: _DevotionalCarousel(
                imageAssets: _templeImageAssets,
                quotes: _devotionalQuotes,
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
              ),
            ),
            const SizedBox(height: 12),
            _PageIndicator(
              currentPage: _currentPage,
              pageCount: _templeImageAssets.length,
            ),
            const SizedBox(height: 24),
            const _DevotionalDivider(),
            const SizedBox(height: 20),
            _QuickActionsGrid(
              staggerController: _gridStagger,
            ),
            const SizedBox(height: 16),
            const _DevotionalTagline(),
          ],
        ),
      ),
    );
  }
}

class _DevotionalCarousel extends StatelessWidget {
  const _DevotionalCarousel({
    required this.imageAssets,
    required this.quotes,
    required this.pageController,
    required this.onPageChanged,
  });

  final List<String> imageAssets;
  final List<String> quotes;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: PageView.builder(
        controller: pageController,
        onPageChanged: onPageChanged,
        itemCount: imageAssets.length,
        itemBuilder: (context, index) {
          final asset = imageAssets[index];
          final quote = quotes[index % quotes.length];

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xFFFFD27D).withOpacity(0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => Container(
                      color: AppTheme.ivory,
                      child: const Center(
                        child: Icon(
                          Icons.account_balance_rounded,
                          size: 64,
                          color: AppTheme.sandalwood,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Text(
                          quote,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            height: 1.3,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD27D).withOpacity(0.24),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Live Temple View',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
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

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.currentPage,
    required this.pageCount,
  });

  final int currentPage;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: currentPage == index
                ? const LinearGradient(
                    colors: [Color(0xFFFFD27D), Color(0xFFFF8F00)],
                  )
                : null,
            color: currentPage == index
                ? null
                : AppTheme.sandalwood.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

class _DevotionalDivider extends StatelessWidget {
  const _DevotionalDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFFFD27D).withOpacity(0.4),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Text(
            '🙏',
            style: TextStyle(fontSize: 20),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD27D).withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.staggerController,
  });

  final AnimationController staggerController;

  static const List<Map<String, dynamic>> _actions = [
    {
      'icon': Icons.people_alt_rounded,
      'label': 'View Data',
      'color': Color(0xFFFF8F00),
    },
    {
      'icon': Icons.camera_alt_rounded,
      'label': 'Camera Monitoring',
      'color': Color(0xFFFF6F00),
    },
    {
      'icon': Icons.analytics_rounded,
      'label': 'Analytics',
      'color': Color(0xFFFFA726),
    },
    {
      'icon': Icons.settings_rounded,
      'label': 'Settings',
      'color': Color(0xFFFFB74D),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final cardW = (constraints.maxWidth - spacing * 3) / 2;
        final cardH = cardW * 0.85;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _AnimatedActionCard(
                    action: _actions[0],
                    staggerController: staggerController,
                    index: 0,
                    minHeight: cardH,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _AnimatedActionCard(
                    action: _actions[1],
                    staggerController: staggerController,
                    index: 1,
                    minHeight: cardH,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            Row(
              children: [
                Expanded(
                  child: _AnimatedActionCard(
                    action: _actions[2],
                    staggerController: staggerController,
                    index: 2,
                    minHeight: cardH,
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: _AnimatedActionCard(
                    action: _actions[3],
                    staggerController: staggerController,
                    index: 3,
                    minHeight: cardH,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  const _AnimatedActionCard({
    required this.action,
    required this.staggerController,
    required this.index,
    required this.minHeight,
  });

  final Map<String, dynamic> action;
  final AnimationController staggerController;
  final int index;
  final double minHeight;

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeOutCubic),
    );
    _slide = Tween<Offset>(
      begin: Offset(0, 0.08 + (widget.index % 2) * 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: widget.staggerController,
        curve: Interval(
          0.2 + widget.index * 0.12,
          0.6 + widget.index * 0.12,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: GestureDetector(
              onTapDown: (_) => _tapController.forward(),
              onTapUp: (_) {
                _tapController.reverse();
              },
              onTapCancel: () => _tapController.reverse(),
              child: Container(
                constraints: BoxConstraints(minHeight: widget.minHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFFFFD27D).withOpacity(0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.action['icon'],
                          size: 28,
                          color: widget.action['color'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.action['label'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.templeBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DevotionalTagline extends StatelessWidget {
  const _DevotionalTagline();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD27D).withOpacity(0.1),
            const Color(0xFFFFF8E7).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD27D).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        '✨ "Where Devotion Meets Technology"',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.templeBrown,
          letterSpacing: 0.2,
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
