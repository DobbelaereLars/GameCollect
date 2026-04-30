import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Wraps `firebase_auth` with a ChangeNotifier surface so that the rest of the
/// app can rebuild on auth state changes without depending on Firebase types
/// directly.
///
/// If Firebase is not configured (placeholder `firebase_options.dart`),
/// [isAvailable] returns false and the service gracefully no-ops.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? _auth;
  User? _user;
  bool _initialized = false;

  bool get isAvailable => _auth != null;
  User? get currentUser => _user;
  bool get isSignedIn => _user != null;
  String? get email => _user?.email;
  String? get uid => _user?.uid;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (Firebase.apps.isEmpty) return;
    try {
      _auth = FirebaseAuth.instance;
      _user = _auth!.currentUser;
      _auth!.authStateChanges().listen((user) {
        _user = user;
        notifyListeners();
      });
    } catch (_) {
      _auth = null;
    }
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    return auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    return auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    final auth = _requireAuth();
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw StateError(
        'Firebase is niet geconfigureerd. Run flutterfire configure.',
      );
    }
    return auth;
  }
}
