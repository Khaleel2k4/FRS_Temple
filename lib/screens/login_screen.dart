import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../widgets/golden_gradient_button.dart';
import '../widgets/temple_immersive_background.dart';
import 'admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  static const String _validEmail = 'nagamjyothi691@gmail.com';
  static const String _validPassword = 'temple_frs@2026';

  static const String _deityAsset = 'assets/images/temple_deity.png';
  static const String? _topLeftDecorAsset = null;
  static const String? _topRightDecorAsset = null;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;

  late final AnimationController _pageController;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;

  late final AnimationController _auraController;
  late final Animation<double> _auraPulse;

  late final AnimationController _bellController;
  late final Animation<double> _bellSwing;
  late final Animation<double> _bellGlow;

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pageFade = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOutCubic,
    );
    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));

    _pageController.forward();

    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _auraPulse = CurvedAnimation(parent: _auraController, curve: Curves.easeInOut);

    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _bellSwing = Tween<double>(begin: -0.18, end: 0.18).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.easeInOutSine),
    );
    _bellGlow = CurvedAnimation(parent: _bellController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _pageController.dispose();
    _auraController.dispose();
    _bellController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email == _validEmail && password == _validPassword) {
      Navigator.of(context).pushReplacement(_divineRoute(const AdminDashboardScreen()));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid Email or Password')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 900;

    final cardMaxWidth = isWide ? 460.0 : 520.0;
    final cardPadding = isWide ? 28.0 : 20.0;

    final auraRadius = (size.shortestSide * 0.62).clamp(260.0, 520.0);

    return Scaffold(
      body: TempleImmersiveBackground(
        backgroundAsset: _deityAsset,
        topLeftDecorationAsset: _topLeftDecorAsset,
        topRightDecorationAsset: _topRightDecorAsset,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _auraController,
                    builder: (context, _) {
                      final p = _auraPulse.value;
                      final intensity = 0.12 + p * 0.16;

                      return Center(
                        child: Container(
                          width: auraRadius,
                          height: auraRadius,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFFD27D)
                                    .withOpacity(intensity),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AnimatedBuilder(
                    animation: _bellController,
                    builder: (context, _) {
                      final t = _bellGlow.value;
                      final vib = math.sin(_bellController.value * math.pi * 10) *
                          0.0025 *
                          (0.25 + 0.75 * t);

                      return Transform.translate(
                        offset: Offset(vib * 20, 0),
                        child: Transform.rotate(
                          angle: _bellSwing.value,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFFFD27D)
                                      .withOpacity(0.18 + t * 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_active_rounded,
                              size: 34,
                              color: const Color(0xFF4E342E)
                                  .withOpacity(0.86 + t * 0.10),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxWidth),
                    child: FadeTransition(
                      opacity: _pageFade,
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          final t = Curves.easeOutCubic.transform(_pageController.value);
                          final scale = 0.92 + t * 0.08;
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: _GlassLoginCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          emailFocus: _emailFocus,
                          passwordFocus: _passwordFocus,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          onLogin: _handleLogin,
                        ),
                      ),
                    ),
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

PageRouteBuilder<T> _divineRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(
        begin: const Offset(0.04, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class _SacredHeader extends StatefulWidget {
  const _SacredHeader({required this.iconSize});

  final double iconSize;

  @override
  State<_SacredHeader> createState() => _SacredHeaderState();
}

class _SacredHeaderState extends State<_SacredHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.iconSize;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            final aura = 0.20 + t * 0.22;
            final scale = 1.0 + t * 0.035;

            return Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: iconSize * 1.7,
                    width: iconSize * 1.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD27D).withOpacity(aura),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Container(
                    height: iconSize,
                    width: iconSize,
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
                          color: const Color(0xFFFFD27D)
                              .withOpacity(0.25 + t * 0.18),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Colors.white,
                      size: iconSize * 0.56,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          'Temple Admin Portal',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Opacity(
          opacity: 0.78,
          child: Text(
            'Sacred Management for a Divine Space',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  letterSpacing: 0.2,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _GlassLoginCard extends StatefulWidget {
  const _GlassLoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.emailFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;

  @override
  State<_GlassLoginCard> createState() => _GlassLoginCardState();
}

class _GlassLoginCardState extends State<_GlassLoginCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cardController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    _fade = CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));

    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (mounted) _cardController.forward();
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderGlow = const Color(0xFFFFD27D);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderGlow.withOpacity(0.45), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: borderGlow.withOpacity(0.20),
                blurRadius: 28,
                spreadRadius: 1.5,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.60),
                      const Color(0xFFFFF8E7).withOpacity(0.38),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Form(
                    key: widget.formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Login',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _AnimatedField(
                          controller: widget.emailController,
                          focusNode: widget.emailFocus,
                          label: 'Email',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => widget.passwordFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _AnimatedField(
                          controller: widget.passwordController,
                          focusNode: widget.passwordFocus,
                          label: 'Password',
                          icon: Icons.lock_rounded,
                          obscureText: widget.obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => widget.onLogin(),
                          suffix: IconButton(
                            onPressed: widget.onToggleObscure,
                            icon: Icon(
                              widget.obscurePassword
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        GoldenGradientButton(
                          label: 'LOGIN',
                          onPressed: widget.onLogin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedField extends StatefulWidget {
  const _AnimatedField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.obscureText = false,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final Widget? suffix;

  @override
  State<_AnimatedField> createState() => _AnimatedFieldState();
}

class _AnimatedFieldState extends State<_AnimatedField> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _AnimatedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final glow = const Color(0xFFFFD27D);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (focused)
            BoxShadow(
              color: glow.withOpacity(0.28),
              blurRadius: 22,
              spreadRadius: 0.6,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator,
        obscureText: widget.obscureText,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: AnimatedScale(
            duration: const Duration(milliseconds: 220),
            scale: focused ? 1.08 : 1.0,
            child: Icon(
              widget.icon,
              color: focused
                  ? const Color(0xFFFF8F00)
                  : const Color(0xFF4E342E).withOpacity(0.80),
            ),
          ),
          suffixIcon: widget.suffix,
        ),
      ),
    );
  }
}
