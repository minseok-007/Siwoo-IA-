import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/dog_traits.dart';
import 'auth_service.dart';
import 'messaging_service.dart';

/// ChangeNotifier that manages authentication state across the app.
/// - Subscribes to FirebaseAuth's `authStateChanges` stream to capture logins, logouts, and profile updates.
/// - Bridges the AuthService and UI layers, encapsulating async handling and error states.
class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final MessagingService _messagingService = MessagingService.instance;
  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;

  /// Convenience accessor for the current user's identifier.
  /// Falls back to the `UserModel` when Firebase's `User` is unavailable
  /// (e.g., in widget tests where only profile data is injected).
  String? get currentUserId => _user?.uid ?? _userModel?.id;

  AuthProvider({AuthService? authService, bool listenAuthChanges = true})
      : _authService = authService ?? AuthService() {
    if (listenAuthChanges) {
      // Subscribe immediately so we keep auth state in sync in real time.
      _init();
    }
  }

  /// Listens to the Firebase auth stream and loads the user document.
  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userModel = null;
        _messagingService.clearUser();
      }
      notifyListeners();
    });
  }

  /// Fetches detailed user data from Firestore and caches it locally.
  Future<void> _loadUserData(String userId) async {
    try {
      _userModel = await _authService.getUserData(userId);
      if (_userModel != null) {
        // Initialize messaging service asynchronously (don't block)
        _messagingService.initializeForUser(_userModel!.id).catchError((e) {
          print('Warning: Failed to initialize messaging service: $e');
        });
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      // Re-throw to allow caller to handle
      rethrow;
    }
  }

  /// Handles email/password sign-up and creates the associated user document when successful.
  /// 
  /// This method performs a complete registration flow:
  /// 1. Creates Firebase Auth account and basic Firestore user document
  /// 2. Creates UserModel with all provided preferences
  /// 3. Updates Firestore with walker preferences if user is a walker
  /// 4. Initializes messaging service in background (non-blocking)
  /// 
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  /// - [fullName]: User's full name
  /// - [userType]: Whether user is a dog owner or dog walker
  /// - [experienceLevel]: Walker's experience level (only used if userType is dogWalker)
  /// - [maxDistance]: Maximum distance walker is willing to travel (km)
  /// - [preferredDogSizes]: List of preferred dog sizes
  /// - [availableDays]: List of available days (0-6, where 0 is Sunday)
  /// - [preferredTimeSlots]: List of preferred time slots (morning, afternoon, evening)
  /// - [preferredTemperaments]: List of preferred dog temperaments
  /// - [preferredEnergyLevels]: List of preferred energy levels
  /// - [supportedSpecialNeeds]: List of special needs the walker can handle
  /// 
  /// Returns:
  /// - [bool]: true if signup was successful, false otherwise
  /// 
  /// Note: Firestore write operations are awaited to ensure data persistence.
  /// Messaging service initialization is non-blocking to prevent signup delays.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserType userType,
    ExperienceLevel experienceLevel = ExperienceLevel.beginner,
    double maxDistance = 10.0,
    List<DogSize> preferredDogSizes = const [],
    List<int> availableDays = const [],
    List<String> preferredTimeSlots = const [],
    List<DogTemperament> preferredTemperaments = const [],
    List<EnergyLevel> preferredEnergyLevels = const [],
    List<SpecialNeeds> supportedSpecialNeeds = const [],
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Step 1: Create Firebase Auth account and basic Firestore document
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
        fullName: fullName,
        userType: userType,
      );
      _user = userCredential.user;
      
      // Step 2: Create user model with all preferences
      _userModel = UserModel(
        id: _user!.uid,
        email: email,
        fullName: fullName,
        userType: userType,
        experienceLevel: experienceLevel,
        maxDistance: maxDistance,
        preferredDogSizes: preferredDogSizes,
        availableDays: availableDays,
        preferredTimeSlots: preferredTimeSlots,
        preferredTemperaments: preferredTemperaments,
        preferredEnergyLevels: preferredEnergyLevels,
        supportedSpecialNeeds: supportedSpecialNeeds,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Step 3: Update Firestore with walker preferences if needed
      if (userType == UserType.dogWalker) {
        try {
          await _authService.updateUserData(_userModel!);
          print('Walker preferences saved to Firestore');
        } catch (e) {
          print('Warning: Failed to update walker preferences: $e');
          // Don't fail signup if preferences update fails
        }
      }
      
      // Step 4: Initialize messaging service in background (non-blocking)
      _messagingService.initializeForUser(_userModel!.id).catchError((e) {
        print('Warning: Failed to initialize messaging service: $e');
      });
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      notifyListeners();
      print('SignUp error: $e');
      return false;
    }
  }

  /// Handles email/password sign-in and refreshes the user document on success.
  /// 
  /// This method performs authentication and loads user data:
  /// 1. Authenticates with Firebase Auth using email/password
  /// 2. Loads user data from Firestore with retry logic (handles eventual consistency)
  /// 3. Returns success/failure status
  /// 
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  /// 
  /// Returns:
  /// - [bool]: true if sign-in was successful, false otherwise
  /// 
  /// Error Handling:
  /// - All errors are caught and converted to generic "Invalid email or password" message
  ///   for security (prevents email enumeration attacks)
  /// - Retries loading user data up to 3 times with 500ms delays to handle Firestore
  ///   eventual consistency issues
  /// 
  /// Note: If user data doesn't exist in Firestore after retries, it's treated as
  /// a login failure for security reasons.
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _clearError();

    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      
      // Retry loading user data if it fails
      // This handles Firestore's eventual consistency where the user document
      // might not be immediately available after creation
      int retries = 3;
      while (retries > 0) {
        try {
          await _loadUserData(_user!.uid);
          break;
        } catch (e) {
          retries--;
          if (retries > 0) {
            // Wait before retrying to allow Firestore to propagate
            await Future.delayed(const Duration(milliseconds: 500));
          } else {
            // If user data doesn't exist after all retries, treat as login failure
            // This prevents unauthorized access and maintains security
            throw Exception('Invalid email or password');
          }
        }
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      // Set generic error message for security
      // Never reveal specific error details (wrong password, email doesn't exist, etc.)
      // to prevent email enumeration and other security attacks
      _setError('Invalid email or password');
      _setLoading(false);
      print('SignIn error: $e');
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
      await _messagingService.clearUser();
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

  /// Testing helper to inject auth state without relying on Firebase streams.
  @visibleForTesting
  void debugSetAuthState({User? user, UserModel? userModel}) {
    _user = user;
    _userModel = userModel;
    notifyListeners();
  }
}
