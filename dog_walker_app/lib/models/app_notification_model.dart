import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple in-app notification model persisted in the `notifications` collection.
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? relatedId;
  final String type;
  final bool read;
  final DateTime createdAt;
  final String createdBy;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.relatedId,
    this.type = 'info',
    this.read = false,
    required this.createdAt,
    required this.createdBy,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      relatedId: data['relatedId'],
      type: data['type'] ?? 'info',
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'type': type,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }
}
