import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../shared/services/auth_service.dart';
import '../shared/services/firestore_service.dart';
import '../shared/services/reviewer_service.dart';
import '../shared/services/notification_service.dart';
import '../shared/services/notification_preferences.dart';
import '../shared/widgets/main_shell.dart';
import 'login_screen.dart';
import '../shared/widgets/whats_new_dialog.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-sync notifications when app comes back to foreground.
  /// This handles the case where the user granted exact alarm permission
  /// in settings while the app was backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _lastUid != null) {
      _resyncOnResume(_lastUid!);
    }
  }

  Future<void> _resyncOnResume(String uid) async {
    final hasPermission =
        await NotificationService.instance.hasExactAlarmPermission();
    if (!hasPermission) return;

    final prefs =
        context.read<NotificationPreferencesController>().prefs;
    if (!prefs.enabled) return;

    final service = FirestoreService(uid: uid);
    final terms = await service.fetchActiveTermClasses();
    if (terms.isEmpty) return;

    await NotificationService.instance.resyncAll(
      terms,
      minutesBefore: prefs.classReminderMinutesBefore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          _lastUid = null;
          return const LoginScreen();
        }

        // First time we see this user — request permission and sync
        if (_lastUid != user.uid) {
          _lastUid = user.uid;

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await NotificationService.instance.requestPermission();

            if (!mounted) return;

            await Future<void>.delayed(const Duration(milliseconds: 300));

            if (!mounted) return;

            await showWhatsNewIfNeeded(context);
          });
        }

        return MultiProvider(
          providers: [
            Provider<FirestoreService>(
              create: (_) => FirestoreService(uid: user.uid),
            ),
            Provider<ReviewerService>(
              create: (_) => ReviewerService(uid: user.uid),
            ),
          ],
          child: const MainShell(),
        );
      },
    );
  }
}