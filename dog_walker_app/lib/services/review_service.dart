import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

/// CRUD/query service for the `reviews` collection.
/// - Also exposes helpers for computing average ratings.
class ReviewService {
  final CollectionReference reviewsCollection = FirebaseFirestore.instance.collection('reviews');

  Future<void> addReview(ReviewModel review) async {
    await reviewsCollection.doc(review.id).set(review.toFirestore());
  }

  Future<List<ReviewModel>> getReviewsForUser(String userId) async {
    final query = await reviewsCollection.where('revieweeId', isEqualTo: userId).get();
    return query.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
  }

  Future<double> getAverageRating(String userId) async {
    final reviews = await getReviewsForUser(userId);
    if (reviews.isEmpty) return 0.0;
    final total = reviews.fold(0.0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  /// Checks if a reviewer already left a review for a specific walk.
  Future<bool> hasReview({required String reviewerId, required String walkId}) async {
    final query = await reviewsCollection
        .where('reviewerId', isEqualTo: reviewerId)
        .where('walkId', isEqualTo: walkId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Recomputes and updates the user's average rating in the `users` collection.
  Future<void> updateUserAverageRating(String userId) async {
    final avg = await getAverageRating(userId);
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'rating': avg,
    });
  }
} 
