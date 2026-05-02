import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Omhult `firebase_auth` met een ChangeNotifier-interface zodat de rest van de
/// app kan herbouwen bij authenticatiewijzigingen zonder directe Firebase-afhankelijkheid.
///
/// Als Firebase niet geconfigureerd is (placeholder `firebase_options.dart`),
/// geeft [isAvailable] false terug en doet de service niets.
class AuthService extends ChangeNotifier {
  AuthService._();

  /// Singleton-instantie, globaal toegankelijk.
  static final AuthService instance = AuthService._();

  // Interne Firebase Auth-referentie; null als Firebase niet beschikbaar is.
  FirebaseAuth? _auth;

  // Huidig ingelogde gebruiker; null als uitgelogd.
  User? _user;

  // Voorkomt dubbele initialisatie.
  bool _initialized = false;

  /// Geeft aan of Firebase Auth beschikbaar is op dit toestel.
  bool get isAvailable => _auth != null;

  /// De huidig ingelogde Firebase-gebruiker, of null.
  User? get currentUser => _user;

  /// True als er een gebruiker ingelogd is.
  bool get isSignedIn => _user != null;

  /// E-mailadres van de ingelogde gebruiker, of null.
  String? get email => _user?.email;

  /// UID van de ingelogde gebruiker, of null.
  String? get uid => _user?.uid;

  /// Initialiseert de service en luistert op auth-statuswijzigingen.
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

  /// Meldt de gebruiker aan met e-mail en wachtwoord.
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

  /// Registreert een nieuwe gebruiker met e-mail en wachtwoord.
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

  /// Meldt de huidige gebruiker af.
  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  /// Verstuurt een wachtwoord-reset-e-mail naar het opgegeven adres.
  Future<void> sendPasswordReset(String email) async {
    final auth = _requireAuth();
    await auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Gooit een [StateError] als Firebase niet geconfigureerd is.
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
