import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// ChangeNotifier that manages authentication state across the app.
/// - Subscribes to FirebaseAuth's `authStateChanges` stream to capture logins, logouts, and profile updates.
/// - Bridges the AuthService and UI layers, encapsulating async handling and error states.
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
    // Subscribe immediately so we keep auth state in sync in real time.
    _init();
  }

  /// Listens to the Firebase auth stream and loads the user document.
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

  /// Fetches detailed user data from Firestore and caches it locally.
  Future<void> _loadUserData(String userId) async {
    try {
      _userModel = await _authService.getUserData(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Handles email/password sign-up and creates the associated user document when successful.
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

  /// Handles email/password sign-in and refreshes the user document on success.
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

  /// Handles sign-out, resetting local state and notifying listeners.
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

  /// Password reset placeholder; production should invoke Firebase's email workflow.
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

  /// Updates the user profile and refreshes the local cache.
  Future<void> updateUserProfile(UserModel updatedUser) async {
    _setLoading(true);
    _clearError();

    try {
      // Persist to Firestore and update local state
      final toSave = updatedUser.copyWith(updatedAt: DateTime.now());
      await _authService.updateUserData(toSave);
      _userModel = toSave;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // Helpers to keep state mutations and notifications consistent.
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
