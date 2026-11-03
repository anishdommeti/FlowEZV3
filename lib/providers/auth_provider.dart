import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required this.authService,
  }) {
    _authStateSubscription = authService.authStateChanges().listen(_handleAuthStateChange);
  }

  final AuthService authService;

  StreamSubscription<User?>? _authStateSubscription;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String role = 'customer',
  }) async {
    await _execute(() async {
      _currentUser = await authService.createUser(
        name: name,
        email: email,
        password: password,
        role: role,
      );
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String role = 'user',
  }) {
    return register(
      name: name,
      email: email,
      password: password,
      role: role,
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _execute(() async {
      _currentUser = await authService.signIn(email: email, password: password);
    });
  }

  Future<void> signOut() async {
    await _execute(() async {
      await authService.signOut();
      _currentUser = null;
    });
  }

  Future<void> reloadProfile() async {
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    await _execute(() async {
      _currentUser = await authService.getUserProfile(firebaseUser.uid);
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _execute(() => authService.sendPasswordResetEmail(email));
  }

  Future<void> resetPassword(String email) {
    return sendPasswordResetEmail(email);
  }

  Future<void> _handleAuthStateChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _error = null;
      notifyListeners();
      return;
    }

    try {
      _currentUser = await authService.getUserProfile(firebaseUser.uid);
      _error = null;
    } catch (error) {
      _error = error.toString();
    }

    notifyListeners();
  }

  Future<void> _execute(Future<void> Function() action) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
