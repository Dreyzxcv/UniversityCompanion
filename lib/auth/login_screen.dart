// lib/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../shared/services/auth_service.dart';
import '../shared/theme/app_theme.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _showEmailForm = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();

      await auth.logIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      // AuthGate listens to authStateChanges
      // and will route on successful login.
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();

    if (msg.contains('user-not-found') ||
        msg.contains('wrong-password') ||
        msg.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }

    if (msg.contains('invalid-email')) {
      return 'That email address looks invalid.';
    }

    return 'Something went wrong. Please try again.';
  }

  void _comingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-in is coming soon.'),
      ),
    );
  }

  void _goBackToChoices() {
    setState(() {
      _showEmailForm = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned.fill(
                  child: _Header(
                    showBack: _showEmailForm,
                    onBack: _goBackToChoices,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          32,
                          24,
                          24,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(
                            milliseconds: 280,
                          ),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _showEmailForm
                              ? _buildEmailForm()
                              : _buildChoices(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChoices() {
    return Column(
      key: const ValueKey('choices'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Login Account',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 6),

        Text(
          "Choose how you'd like to continue",
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 36),

        // EMAIL
        _ChoiceButton(
          svgIcon: 'lib/images/mail.svg',
          label: 'Continue with Email',
          filled: true,
          onTap: () {
            setState(() {
              _showEmailForm = true;
            });
          },
        ),

        const SizedBox(height: 14),

        // GOOGLE
        _ChoiceButton(
          svgIcon: 'lib/images/google.svg',
          label: 'Continue with Google',
          filled: false,
          onTap: () => _comingSoon('Google'),
        ),

        const SizedBox(height: 32),

        // SIGN UP
        const _SignupFooter(),
      ],
    );
  }

  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('emailForm'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Login with Email',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Text(
            'Enter your school email and password',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'School email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || !v.contains('@')) {
                return 'Enter a valid email';
              }

              return null;
            },
          ),

          const SizedBox(height: 14),

          TextFormField(
            controller: _passwordCtrl,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_loading) {
                _submit();
              }
            },
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'At least 6 characters';
              }

              return null;
            },
          ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _comingSoon('Password reset'),
              child: const Text(
                'Forgot Password?',
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.overdue,
                fontSize: 13,
              ),
            ),
          ],

          const SizedBox(height: 16),

          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Login'),
          ),

          const SizedBox(height: 20),

          // SIGN UP
          const _SignupFooter(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool showBack;
  final VoidCallback onBack;

  const _Header({
    required this.showBack,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: Stack(
        children: [
          if (showBack)
            Positioned(
              left: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
                onPressed: onBack,
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(
              milliseconds: 350,
            ),
            curve: Curves.easeOutCubic,
            top: showBack ? 105 : 105,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 350,
                  ),
                  curve: Curves.easeOutCubic,
                  width: showBack ? 100 : 100,
                  height: showBack ? 100 : 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(
                          0,
                          6,
                        ),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'lib/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'UNIVERSITY COMPANION',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData? icon;
  final String? svgIcon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ChoiceButton({
    this.icon,
    this.svgIcon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget buttonIcon;

    if (svgIcon != null) {
      buttonIcon = SvgPicture.asset(
        svgIcon!,
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
    } else if (icon != null) {
      buttonIcon = Icon(
        icon,
        size: 20,
      );
    } else {
      buttonIcon = const SizedBox(
        width: 20,
        height: 20,
      );
    }

    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buttonIcon,

        const SizedBox(width: 10),

        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );

    if (filled) {
      return FilledButton(
        onPressed: onTap,
        child: content,
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      child: content,
    );
  }
}

class _SignupFooter extends StatelessWidget {
  const _SignupFooter();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SignupScreen(),
              ),
            );
          },
          child: const Text(
            'Create Account',
            style: TextStyle(
              color: AppColors.navyDark,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
