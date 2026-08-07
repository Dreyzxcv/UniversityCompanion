import 'package:flutter/material.dart';
import '../shared/theme/app_theme.dart';
import 'auth_gate.dart';

/// Launch screen: fades/scales the app logo in, holds briefly, then hands
/// off to [AuthGate]. The logo is wrapped in a [Hero] tagged 'app-logo' —
/// [LoginScreen] wraps its header logo in the same tag, so the Navigator
/// automatically animates the logo flying from here into its resting spot
/// at the top of the login screen instead of just cutting to it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _goToAuthGate();
  }

  Future<void> _goToAuthGate() async {
    // Hold on the splash long enough for the fade/scale-in to finish and
    // register with the user before flying into the login header.
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const AuthGate(),
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
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Hero(
              tag: 'app-logo',
              child: Image.asset(
                'lib/images/logo.png',
                width: 120,
                height: 120,
              ),
            ),
          ),
        ),
      ),
    );
  }
}