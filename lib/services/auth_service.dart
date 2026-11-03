import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserModel> createUser({
    required String name,
    required String email,
    required String password,
    String role = 'customer',
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthServiceException('User account could not be created.');
    }

    await firebaseUser.updateDisplayName(name.trim());

    final userModel = UserModel(
      uid: firebaseUser.uid,
      name: name.trim(),
      email: email.trim(),
      role: role,
      createdAt: DateTime.now().toUtc(),
      joinedQueues: const [],
    );

    await _firestore
        .collection('users')
        .doc(firebaseUser.uid)
        .set(userModel.toMap());

    return userModel;
  }

  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthServiceException('User sign-in failed.');
    }

    return getUserProfile(firebaseUser.uid);
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserModel> getUserProfile(String uid) async {
    final document = await _firestore.collection('users').doc(uid).get();
    final data = document.data();
    if (!document.exists || data == null) {
      throw const AuthServiceException('User profile was not found.');
    }

    return UserModel.fromMap(data);
  }

  Future<UserModel> updateUserProfile(UserModel user) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null && firebaseUser.uid == user.uid) {
      await firebaseUser.updateDisplayName(user.name.trim());
    }

    await _firestore.collection('users').doc(user.uid).update(user.toMap());
    return user;
  }

  Future<void> changePassword(String newPassword) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const AuthServiceException('No authenticated user is available.');
    }

    await firebaseUser.updatePassword(newPassword);
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
