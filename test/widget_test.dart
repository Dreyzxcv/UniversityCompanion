// Basic smoke test for University Companion.
//
// The default Flutter template test (looking for a counter and a '+'
// button) doesn't apply to this app, so this instead verifies that the
// app boots into SplashScreen and shows the logo without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:university_companion_app/auth/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders logo and fades in', (WidgetTester tester) async {
    // Pump SplashScreen directly (rather than the full app) to avoid
    // needing a real Firebase.initializeApp() call in a widget test.
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial frame: animation hasn't completed yet, but the logo image
    // should already be in the tree (fading in via Hero + AnimationController).
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Hero), findsOneWidget);

    // Advance past the fade/scale-in animation (900ms) without yet
    // triggering the 1600ms delayed navigation to AuthGate.
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}