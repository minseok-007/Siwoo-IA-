import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String reviewerId;
  final String revieweeId;
  final String walkId;
  final double rating;
  final String comment;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    required this.walkId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      reviewerId: data['reviewerId'] ?? '',
      revieweeId: data['revieweeId'] ?? '',
      walkId: data['walkId'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'walkId': walkId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
} 