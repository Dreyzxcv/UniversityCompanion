import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/services/auth_service.dart';
import '../shared/services/firestore_service.dart';
import '../shared/widgets/main_shell.dart';
import 'login_screen.dart';

/// Gates access to the rest of the app behind Firebase Auth, per the
/// requirement that Schedule and QPI Calculator are only reachable when
/// logged in. Rebuilds the FirestoreService (scoped to the current uid)
/// whenever the signed-in user changes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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
          return const LoginScreen();
        }

        return Provider<FirestoreService>(
          create: (_) => FirestoreService(uid: user.uid),
          child: const MainShell(),
        );
      },
    );
  }
}
