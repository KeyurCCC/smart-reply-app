import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;
  final UserRepository userRepository;

  AuthRepositoryImpl({
    required this.firebaseAuth,
    required this.googleSignIn,
    required this.userRepository,
  });

  @override
  Stream<User?> authStateChanges() => firebaseAuth.authStateChanges();

  @override
  User? get currentUser => firebaseAuth.currentUser;

  @override
  String? get currentUserId => currentUser?.uid;

  @override
  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await firebaseAuth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      await user.getIdToken();
      await userRepository.createOrUpdateUser(
        AppUser(
          id: user.uid,
          displayName: user.displayName ?? 'User',
          email: (user.email ?? '').toLowerCase(),
          photoUrl: user.photoURL,
          createdAt: DateTime.now(),
        ),
      );
    }

    return userCredential;
  }

  @override
  Future<void> signOut() async {
    await Future.wait([
      firebaseAuth.signOut(),
      googleSignIn.signOut(),
    ]);
  }

  @override
  Future<void> ensureAuthReady() async {
    final user = firebaseAuth.currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }
  }
}
