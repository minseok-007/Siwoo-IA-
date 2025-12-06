import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Lightweight auth service that runs locally without Firebase.
/// - Suited for sample/offline scenarios; stores passwords in plain text and is insecure.
/// - Use FirebaseAuth or another secure provider in production.
class LocalAuthService {
  static const String _usersKey = 'users';
  static const String _currentUserKey = 'current_user';

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson != null) {
      final userData = json.decode(userJson);
      return UserModel(
        id: userData['id'],
        email: userData['email'],
        fullName: userData['fullName'],
        userType: userData['userType'] == 'dogOwner' ? UserType.dogOwner : UserType.dogWalker,
        createdAt: DateTime.parse(userData['createdAt']),
        updatedAt: DateTime.parse(userData['updatedAt']),
      );
    }
    return null;
  }

  // Sign up
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserType userType,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '[]';
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));

      // Check if user already exists
      if (users.any((user) => user['email'] == email)) {
        throw Exception('User already exists');
      }

      // Create new user
      final newUser = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'email': email,
        'password': password, // In real app, this should be hashed
        'fullName': fullName,
        'userType': userType == UserType.dogOwner ? 'dogOwner' : 'dogWalker',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      users.add(newUser);
      await prefs.setString(_usersKey, json.encode(users));
      await prefs.setString(_currentUserKey, json.encode(newUser));

      return true;
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }

  // Sign in
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '[]';
      final users = List<Map<String, dynamic>>.from(json.decode(usersJson));

      final user = users.firstWhere(
        (user) => user['email'] == email && user['password'] == password,
        orElse: () => throw Exception('Invalid credentials'),
      );

      await prefs.setString(_currentUserKey, json.encode(user));
      return true;
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Reset password (simplified)
  Future<void> resetPassword(String email) async {
    // In a real app, this would send an email
    // For local storage, we'll just return success
    return;
  }

  // Check if user exists
  Future<bool> userExists(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey) ?? '[]';
    final users = List<Map<String, dynamic>>.from(json.decode(usersJson));
    return users.any((user) => user['email'] == email);
  }
} 
