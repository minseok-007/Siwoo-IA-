import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase Cloud Messaging permissions, token persistence, and
/// foreground presentation defaults.
class MessagingService {
  MessagingService._();

  static final MessagingService instance = MessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentUserId;
  String? _cachedToken;

  /// Configure platform-specific defaults (foreground notification behavior).
  Future<void> configureGlobalSettings() async {
    if (!kIsWeb) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// Requests permissions (when needed) and stores the device token for the user.
  Future<void> initializeForUser(String userId) async {
    _currentUserId = userId;

    if (!kIsWeb) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
    }

    final token = await _getToken();
    if (token != null) {
      _cachedToken = token;
      await _saveToken(userId, token);
    }

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      try {
        _cachedToken = token;
        if (_currentUserId != null) {
          await _saveToken(_currentUserId!, token);
        }
      } catch (e, stack) {
        debugPrint('FCM onTokenRefresh error: $e\n$stack');
      }
    }, onError: (error, stack) {
      debugPrint('FCM onTokenRefresh stream error: $error');
    });
  }

  Future<void> clearUser() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _currentUserId = null;
    _cachedToken = null;
  }

  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        const vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');
        return _messaging.getToken(
          vapidKey: vapidKey.isEmpty ? null : vapidKey,
        );
      }
      return await _messaging.getToken();
    } on FirebaseException catch (e, stack) {
      debugPrint('FirebaseMessaging getToken error (${e.code}): ${e.message}\n$stack');
      return null;
    } catch (e, stack) {
      debugPrint('FirebaseMessaging getToken unexpected error: $e\n$stack');
      return null;
    }
  }

  Future<void> _saveToken(String userId, String token) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('deviceTokens')
        .doc(token);

    await docRef.set({
      'token': token,
      'platform': describeEnum(defaultTargetPlatform),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
