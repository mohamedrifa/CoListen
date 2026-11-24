import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;
  final GoogleSignIn _googleSignIn;

  AuthRepositoryImpl({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _database = database ?? FirebaseDatabase.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  @override
  Stream<UserEntity?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return UserEntity(
        uid: user.uid,
        displayName: user.displayName ?? (user.isAnonymous ? 'Guest Listener' : 'User'),
        photoUrl: user.photoURL,
        email: user.email,
        isAnonymous: user.isAnonymous,
      );
    });
  }

  @override
  UserEntity? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return UserEntity(
      uid: user.uid,
      displayName: user.displayName ?? (user.isAnonymous ? 'Guest Listener' : 'User'),
      photoUrl: user.photoURL,
      email: user.email,
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  Future<UserEntity> signInAnonymously(String displayName) async {
    final userCredential = await _auth.signInAnonymously();
    final user = userCredential.user!;
    final trimmedName = displayName.trim().isEmpty ? 'Guest Listener' : displayName.trim();

    await user.updateDisplayName(trimmedName);
    await _syncUserToDatabase(user.uid, trimmedName, null, true);

    return UserEntity(
      uid: user.uid,
      displayName: trimmedName,
      isAnonymous: true,
    );
  }

  @override
  Future<UserEntity> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign in was cancelled');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;
    final name = user.displayName ?? googleUser.displayName ?? 'Google User';

    await _syncUserToDatabase(user.uid, name, user.photoURL, false);

    return UserEntity(
      uid: user.uid,
      displayName: name,
      photoUrl: user.photoURL,
      email: user.email,
      isAnonymous: false,
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<void> _syncUserToDatabase(
    String uid,
    String displayName,
    String? photoUrl,
    bool isAnonymous,
  ) async {
    await _database.ref('users/$uid').update({
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isAnonymous': isAnonymous,
      'lastLogin': ServerValue.timestamp,
    });
  }
}
