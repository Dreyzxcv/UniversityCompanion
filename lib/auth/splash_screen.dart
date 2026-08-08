import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shared/theme/app_theme.dart';
import 'auth_gate.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../shared/services/auth_service.dart';
import 'login_screen.dart';


/// Launch screen with a distinctive multi-stage entrance:
///  1. A ring of particles spins and converges toward the center.
///  2. The logo resolves from blurred to sharp as it lands (Hero-tagged
///     'app-logo' so it continues into LoginScreen's header).
///  3. The title types on letter-by-letter with a staggered rise.
/// Then hands off to [AuthGate].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _title = 'UNIVERSITY COMPANION';

  late final AnimationController _controller;

  // Particles converge + spin during the first ~55% of the timeline.
  late final Animation<double> _ringProgress;
  // Logo blurs into focus and scales up, overlapping the ring's finish.
  late final Animation<double> _logoProgress;
  // Title letters stagger in during the back half.
  late final Animation<double> _textProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _ringProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeInCubic),
    );
    _logoProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOutBack),
    );
    _textProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
    _goToNextScreen();
  }

  Future<void> _goToNextScreen() async {
    // Hold a beat after the entrance finishes before handing off.
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Route straight to LoginScreen when logged out so its Hero-tagged
    // logo is present at push time and the flight animates correctly.
    // AuthGate's loading spinner would otherwise sit in between and the
    // Hero would have nothing to fly toward on this frame.
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.currentUser != null;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>
            isLoggedIn ? const AuthGate() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Converging particle ring, fades out once it lands.
                      if (_ringProgress.value < 1.0)
                        CustomPaint(
                          size: const Size(180, 180),
                          painter: _OrbitPainter(t: _ringProgress.value),
                        ),
                      // Logo: blur-to-focus + elastic scale-in.
                      _BlurringLogo(t: _logoProgress.value),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _StaggeredText(text: _title, t: _textProgress.value),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Draws N dots spinning around a shrinking, fading ring — the "particles
/// converging" effect that precedes the logo landing.
class _OrbitPainter extends CustomPainter {
  final double t; // 0 -> 1
  static const _dotCount = 10;

  _OrbitPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = ui.lerpDouble(84.0, 0.0, Curves.easeIn.transform(t))!;
    final opacity = (1.0 - t).clamp(0.0, 1.0);
    final spin = t * math.pi * 3; // a few full spins as it collapses

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _dotCount; i++) {
      final angle = (2 * math.pi * i / _dotCount) + spin;
      final dotCenter = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final dotSize = ui.lerpDouble(2.5, 5.0, i / _dotCount)!;
      paint.color = Colors.white.withOpacity(opacity * 0.85);
      canvas.drawCircle(dotCenter, dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) => oldDelegate.t != t;
}

/// Logo that resolves from blurred/small to sharp/full-size.
class _BlurringLogo extends StatelessWidget {
  final double t; // 0 -> 1
  const _BlurringLogo({required this.t});

  @override
  Widget build(BuildContext context) {
    final clamped = t.clamp(0.0, 1.0);
    final blurSigma = ui.lerpDouble(14.0, 0.0, clamped)!;
    final scale = ui.lerpDouble(0.5, 1.0, clamped)!;

    return Opacity(
      opacity: Curves.easeIn.transform(clamped),
      child: Transform.scale(
        scale: scale,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Hero(
            tag: 'app-logo',
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('lib/images/logo.png', fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders [text] with each letter fading + rising in on its own delay,
/// so the title "types on" rather than fading in as one block.
class _StaggeredText extends StatelessWidget {
  final String text;
  final double t; // 0 -> 1, overall progress for the whole string
  const _StaggeredText({required this.text, required this.t});

  @override
  Widget build(BuildContext context) {
    final letters = text.characters.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(letters.length, (i) {
        // Stagger each letter's window across the available progress.
        final start = i / letters.length;
        final end = ((i + 3) / letters.length).clamp(0.0, 1.0);
        final local = ((t - start) / (end - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(local);

        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, ui.lerpDouble(8, 0, eased)!),
            child: Text(
              letters[i] == ' ' ? '\u00A0\u00A0' : letters[i],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ),
        );
      }),
    );
  }
}