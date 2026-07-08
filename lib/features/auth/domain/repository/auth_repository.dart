import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();

  User? get currentUser;

  String? get currentUserId => currentUser?.uid;

  Future<UserCredential> signInWithGoogle();

  Future<void> signOut();

  /// Ensures the Firebase Auth ID token is available to Firestore.
  Future<void> ensureAuthReady();
}
