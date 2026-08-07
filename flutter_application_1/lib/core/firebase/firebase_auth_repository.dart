import 'package:firebase_auth/firebase_auth.dart';

import 'perdaride_firebase.dart';

class FirebaseAuthRepository {
  FirebaseAuthRepository(this._firebase);

  final PerdaRideFirebase _firebase;

  User? get currentUser => _firebase.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebase.auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _firebase.auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() {
    return _firebase.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebase.auth.sendPasswordResetEmail(email: email);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in user with an email/password account.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}
