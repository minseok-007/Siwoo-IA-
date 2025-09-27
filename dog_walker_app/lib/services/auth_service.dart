// Firebase authentication and Firestore imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Local model imports
import '../models/user_model.dart';

/// Authentication service that handles user authentication and profile management.
/// 
/// This service provides a clean abstraction layer over Firebase Auth and Firestore,
/// allowing the UI layer to work with domain models instead of Firebase-specific types.
/// 
/// Key responsibilities:
/// - User registration and authentication
/// - User profile creation and management
/// - Authentication state monitoring
/// - Error handling and user feedback
/// 
/// Architecture benefits:
/// - Centralizes Firebase SDK dependencies
/// - Provides consistent error handling
/// - Enables easy testing with mock implementations
/// - Decouples UI from Firebase implementation details
class AuthService {
  // Firebase service instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets the currently authenticated user from Firebase Auth.
  /// 
  /// Returns null if no user is currently signed in.
  /// This is a synchronous getter that provides immediate access to the current user.
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  /// 
  /// This stream emits:
  /// - A User object when a user signs in
  /// - null when a user signs out
  /// - The current user state on subscription
  /// 
  /// Used by AuthProvider to automatically update UI based on auth state.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Creates a new user account with email and password authentication.
  /// 
  /// This method performs a complete user registration flow:
  /// 1. Creates Firebase Auth user with email/password
  /// 2. Creates corresponding user document in Firestore
  /// 3. Returns the authentication credentials
  /// 
  /// Parameters:
  /// - [email]: User's email address (must be valid and unique)
  /// - [password]: User's password (minimum 6 characters)
  /// - [fullName]: User's display name
  /// - [phoneNumber]: User's contact number
  /// - [userType]: Whether user is a dog owner or dog walker
  /// 
  /// Returns:
  /// - [UserCredential] containing authentication details
  /// 
  /// Throws:
  /// - [Exception] if registration fails (email already exists, weak password, etc.)
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserType userType,
  }) async {
    try {
      // Step 1: Create Firebase Auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 2: Create user profile document in Firestore
      UserModel userModel = UserModel(
        id: userCredential.user!.uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
        userType: userType,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Step 3: Persist user data to Firestore
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userModel.toFirestore());

      return userCredential;
    } catch (e) {
      // Re-throw with user-friendly error message
      throw Exception('Failed to create account: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Update user data
  Future<void> updateUserData(UserModel userModel) async {
    try {
      await _firestore
          .collection('users')
          .doc(userModel.id)
          .update(userModel.toFirestore());
    } catch (e) {
      throw Exception('Failed to update user data: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Check if user exists
  Future<bool> userExists(String email) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check if user exists: $e');
    }
  }
} 
