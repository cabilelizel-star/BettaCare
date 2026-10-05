import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _firebaseUser;
  AppUser? _appUser;
  bool _loading = true;

  User? get firebaseUser => _firebaseUser;
  AppUser? get appUser => _appUser;
  bool get loading => _loading;
  bool get isLoggedIn => _firebaseUser != null;
  bool get isOwner {
    if (_appUser != null) return _appUser!.isOwner;
    final email = _firebaseUser?.email?.toLowerCase() ?? '';
    return email == 'rzeilan10@gmail.com' || email.contains('owner') || email.contains('admin');
  }
  bool get isCustomer => !isOwner;

  AppAuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) async {
      _firebaseUser = user;
      if (user != null) {
        _appUser = await _authService.getAppUser(user.uid);
      } else {
        _appUser = null;
      }
      _loading = false;
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      final credential = await _authService.login(email, password);
      if (credential.user != null) {
        _firebaseUser = credential.user;
        _appUser = await _authService.getAppUser(credential.user!.uid);
        notifyListeners();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Login failed. Please check your credentials and try again.';
    }
  }

  Future<String?> register(String email, String password, String name) async {
    try {
      final credential = await _authService.register(email, password, name);
      if (credential.user != null) {
        _appUser = await _authService.getAppUser(credential.user!.uid);
        notifyListeners();
      }
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Registration failed. Please try again.';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (e) {
      return 'Could not send password reset email. Please try again.';
    }
  }

  Future<String?> createOwner(
      String email, String password, String name) async {
    try {
      await _authService.createOwner(email, password, name);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<bool> ownerExists() => _authService.ownerExists();

  Future<void> logout() async {
    await _authService.logout();
    _firebaseUser = null;
    _appUser = null;
    notifyListeners();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'No account found with these credentials.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email address is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please check your connection and try again.';
    }
  }
}
