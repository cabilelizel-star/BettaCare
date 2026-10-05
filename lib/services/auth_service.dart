import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get user role & details from Firestore with robust email fallback
  Future<AppUser?> getAppUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!);
      }

      // If document doesn't exist in Firestore, resolve role by email
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        final emailLower = user.email!.toLowerCase();
        final isOwnerEmail = emailLower == 'rzeilan10@gmail.com' ||
            emailLower.contains('owner') ||
            emailLower.contains('admin');
        final role = isOwnerEmail ? 'owner' : 'user';

        final appUser = AppUser(
          uid: uid,
          email: user.email!,
          name: user.displayName ?? user.email!.split('@')[0],
          role: role,
          createdAt: DateTime.now().toIso8601String(),
        );

        // Auto-persist user doc to Firestore
        await _db.collection('users').doc(uid).set(appUser.toMap());
        return appUser;
      }
      return null;
    } catch (e) {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        final emailLower = user.email!.toLowerCase();
        final isOwnerEmail = emailLower == 'rzeilan10@gmail.com' ||
            emailLower.contains('owner') ||
            emailLower.contains('admin');
        return AppUser(
          uid: uid,
          email: user.email!,
          name: user.displayName ?? user.email!.split('@')[0],
          role: isOwnerEmail ? 'owner' : 'user',
          createdAt: DateTime.now().toIso8601String(),
        );
      }
      return null;
    }
  }

  // Login
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Register customer
  Future<UserCredential> register(
    String email,
    String password,
    String name, {
    String role = 'user',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _db.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'email': email.trim(),
      'name': name.trim(),
      'role': role,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return credential;
  }

  // Create owner
  Future<void> createOwner(String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _db.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'email': email.trim(),
      'name': name.trim(),
      'role': 'owner',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // Password reset
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // Check if owner exists
  Future<bool> ownerExists() async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'owner')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
