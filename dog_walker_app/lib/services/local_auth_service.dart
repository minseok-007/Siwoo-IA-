import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Firebase 없이 로컬에서만 동작하는 간이 인증 서비스.
/// - 샘플/오프라인 시나리오 용도이며, 비밀번호 평문 저장 등 보안상 취약합니다.
/// - 실제 서비스에서는 FirebaseAuth 등 안전한 인증 수단을 사용하세요.
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
        phoneNumber: userData['phoneNumber'],
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
    required String phoneNumber,
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
        'phoneNumber': phoneNumber,
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
