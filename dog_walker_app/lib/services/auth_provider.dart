import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Re-enable Firebase auth state changes for real-time updates
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userModel = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserData(String userId) async {
    try {
      _userModel = await _authService.getUserData(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserType userType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        userType: userType,
      );
      _user = userCredential.user;
      await _loadUserData(_user!.uid);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      await _loadUserData(_user!.uid);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _user = null;
      _userModel = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await Future.delayed(Duration(seconds: 1));
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> updateUserProfile(UserModel updatedUser) async {
    _setLoading(true);
    _clearError();

    try {
      _userModel = updatedUser;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
} 