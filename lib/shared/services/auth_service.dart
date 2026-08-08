import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around FirebaseAuth + the `users/{uid}` profile document.
/// Kept separate from FirestoreService so auth concerns (sign up/in/out,
/// email verification) don't mix with app-data reads/writes.
class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email']);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({
    required String name,
    required String school,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name,
      'school': school,
      'email': email,
      'verified': false,
    });

    await cred.user!.sendEmailVerification();
    return cred;
  }

  Future<UserCredential> logIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Signs in with Google. Returns null if the user cancels the picker
  /// (not an error — callers should just no-op in that case).
  /// Creates a `users/{uid}` profile doc on first sign-in, same shape as
  /// the email/password [signUp] path, so the rest of the app (profile
  /// screen, etc.) doesn't need to care which auth method was used.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled the picker

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCred = await _auth.signInWithCredential(credential);
    final user = userCred.user;

    if (user != null) {
      final docRef = _db.collection('users').doc(user.uid);
      final existing = await docRef.get();
      if (!existing.exists) {
        await docRef.set({
          'name': user.displayName ?? '',
          'school': '',
          'email': user.email ?? '',
          // Google accounts arrive pre-verified by Google itself.
          'verified': user.emailVerified,
        });
      }
    }

    return userCred;
  }

  Future<void> logOut() async {
    // Only calls Google sign-out if the current session actually came
    // through Google; harmless no-op otherwise but avoids an unnecessary
    // native call on every logout.
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateProfile({
    required String name,
    required String school,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'name': name,
      'school': school,
    });
  }

  Future<void> reloadAndSyncVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await _db.collection('users').doc(refreshed.uid).update({
        'verified': true,
      });
    }
  }
}