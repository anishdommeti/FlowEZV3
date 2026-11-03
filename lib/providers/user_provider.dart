import 'package:flutter/foundation.dart';

import '../models/token_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/queue_service.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({
    required this.authService,
    required this.queueService,
  });

  final AuthService authService;
  final QueueService queueService;

  UserModel? _user;
  List<TokenModel> _activeTokens = const [];
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  List<TokenModel> get activeTokens => List.unmodifiable(_activeTokens);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCurrentUser() async {
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) {
      _user = null;
      _activeTokens = const [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      _user = await authService.getUserProfile(firebaseUser.uid);
      _activeTokens = await queueService.watchTokensForUser(firebaseUser.uid).first;
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile(UserModel user) async {
    _setLoading(true);
    _error = null;

    try {
      _user = await authService.updateUserProfile(user);
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> changePassword(String newPassword) async {
    _setLoading(true);
    _error = null;

    try {
      await authService.changePassword(newPassword);
    } catch (error) {
      _error = error.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
