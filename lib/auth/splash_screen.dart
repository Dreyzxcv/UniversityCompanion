import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../shared/services/auth_service.dart';
import '../shared/theme/app_theme.dart';
import 'auth_gate.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _title = 'UNIVERSITY COMPANION';

  late final AnimationController _controller;

  // 1. Stamp shape punches in with elastic overshoot
  late final Animation<double> _stampScale;
  // 2. Shape fades out after landing
  late final Animation<double> _shapeFade;
  // 3. Impact ripple expands outward from stamp
  late final Animation<double> _rippleScale;
  late final Animation<double> _rippleFade;
  // 4. Logo reveals after stamp lands
  late final Animation<double> _logoReveal;
  late final Animation<double> _logoScale;
  // 5. Glow behind logo
  late final Animation<double> _glowOpacity;
  // 6. Title types on letter by letter
  late final Animation<double> _textReveal;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Shape stamps down: quick scale up past 1.0, elastic snap back
    _stampScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.25, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45),
      ),
    );

    // Shape fades away so logo stands alone
    _shapeFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.55, curve: Curves.easeIn),
      ),
    );

    // Ripple burst on impact
    _rippleScale = Tween<double>(begin: 0.8, end: 2.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.58, curve: Curves.easeOut),
      ),
    );

    _rippleFade = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.58, curve: Curves.easeOut),
      ),
    );

    // Logo fades + scales in as shape disappears
    _logoReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.38, 0.68, curve: Curves.easeOut),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.68),
      ),
    );

    // Soft glow behind logo, peaks then settles
    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 0.25)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.80),
      ),
    );

    // Title staggered reveal
    _textReveal = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
    _goToNextScreen();
  }

  Future<void> _goToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.currentUser != null;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>
            isLoggedIn ? const AuthGate() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow layer behind everything
                      Opacity(
                        opacity: _glowOpacity.value,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.18),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                              BoxShadow(
                                color: AppColors.navyMid.withOpacity(0.6),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Ripple ring burst on stamp impact
                      if (_rippleFade.value > 0)
                        Opacity(
                          opacity: _rippleFade.value,
                          child: Transform.scale(
                            scale: _rippleScale.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Second, wider ripple ring (slight delay feel)
                      if (_rippleFade.value > 0)
                        Opacity(
                          opacity: _rippleFade.value * 0.5,
                          child: Transform.scale(
                            scale: _rippleScale.value * 1.3,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Stamp shape: rounded square that punches in
                      if (_shapeFade.value > 0)
                        Opacity(
                          opacity: _shapeFade.value,
                          child: Transform.scale(
                            scale: _stampScale.value,
                            child: _StampShape(),
                          ),
                        ),

                      // Logo: reveals as stamp fades
                      if (_logoReveal.value > 0)
                        Opacity(
                          opacity: _logoReveal.value,
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Hero(
                              tag: 'app-logo',
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.35 * _logoReveal.value),
                                      blurRadius: 30,
                                      offset: const Offset(0, 14),
                                    ),
                                    BoxShadow(
                                      color: AppColors.navyMid
                                          .withOpacity(0.4 * _logoReveal.value),
                                      blurRadius: 20,
                                      spreadRadius: 4,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Image.asset(
                                  'lib/images/logo.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Staggered title
                _StaggeredTitle(
                  text: _title,
                  t: _textReveal.value,
                ),

                const SizedBox(height: 12),

                // Tagline fades in after title
                _TaglineFade(t: _textReveal.value),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stamp shape: the rounded-square "punch" that appears first
// ---------------------------------------------------------------------------

class _StampShape extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(128, 128),
      painter: _StampPainter(),
    );
  }
}

class _StampPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(32));

    // Outer glow
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(8),
        const Radius.circular(36),
      ),
      glowPaint,
    );

    // Main shape fill with gradient
    final gradient = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.width, size.height),
      [
        AppColors.navyMid,
        const Color(0xFF3D4FA0),
      ],
    );

    final fillPaint = Paint()..shader = gradient;
    canvas.drawRRect(rrect, fillPaint);

    // Subtle inner highlight at top
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1),
        const Radius.circular(31),
      ),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Staggered title — each letter rises + fades independently
// ---------------------------------------------------------------------------

class _StaggeredTitle extends StatelessWidget {
  final String text;
  final double t; // 0 → 1 overall progress

  const _StaggeredTitle({required this.text, required this.t});

  @override
  Widget build(BuildContext context) {
    final letters = text.characters.toList();
    final count = letters.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        // Each letter has its own staggered window within [0, 1]
        final start = i / count;
        final end = ((i + 4) / count).clamp(0.0, 1.0);
        final local = ((t - start) / (end - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(local);

        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, ui.lerpDouble(10, 0, eased)!),
            child: Text(
              letters[i] == ' ' ? '\u00A0\u00A0' : letters[i],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.4,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Tagline: fades in slightly after the title finishes
// ---------------------------------------------------------------------------

class _TaglineFade extends StatelessWidget {
  final double t;
  const _TaglineFade({required this.t});

  @override
  Widget build(BuildContext context) {
    // Only starts appearing in the back half of the text reveal
    final local = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(local);

    return Opacity(
      opacity: eased * 0.6,
      child: Transform.translate(
        offset: Offset(0, ui.lerpDouble(6, 0, eased)!),
        child: const Text(
          'Your campus life, organized.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}