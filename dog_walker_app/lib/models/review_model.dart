/* Summary: Manage ratings/reviews as a dedicated model to improve recommendation quality
   and trust. WHAT/HOW: Store the minimal sortable/filterable fields with normalized
   Timestamps. */
import 'package:cloud_firestore/cloud_firestore.dart';

// Keep reviews as a domain model so recommendation and trust scoring have solid inputs.
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

  // Normalize type conversions when restoring external data into the app model.
  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      reviewerId: data['reviewerId'] ?? '',
      revieweeId: data['revieweeId'] ?? '',
      walkId: data['walkId'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(), // Convert to double to preserve precision
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(), // Serves as the basis for sorting/filtering
    );
  }

  // Serialize only the essential fields to keep analysis and sorting straightforward.
  Map<String, dynamic> toFirestore() {
    return {
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'walkId': walkId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp), // Keeps server-aligned ordering
    };
  }
} 
