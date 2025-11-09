import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification_model.dart';

/// Lightweight wrapper around the `notifications` collection.
class NotificationService {
  final CollectionReference _notificationsCollection =
      FirebaseFirestore.instance.collection('notifications');

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String createdBy,
    String? relatedId,
    String type = 'info',
  }) async {
    final notification = AppNotification(
      id: '',
      userId: userId,
      title: title,
      body: body,
      relatedId: relatedId,
      type: type,
      read: false,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _notificationsCollection.add(notification.toFirestore());
  }

  Future<List<AppNotification>> fetchNotificationsForUser(String userId) async {
    final snapshot = await _notificationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => AppNotification.fromFirestore(doc))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationsCollection.doc(notificationId).update({'read': true});
  }
}
