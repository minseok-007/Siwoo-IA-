import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
import 'rating_algorithm_service.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// CRUD/query service for the `reviews` collection.
/// - Also exposes helpers for computing average ratings.
class ReviewService {
  final CollectionReference reviewsCollection = FirebaseFirestore.instance.collection('reviews');

  Future<void> addReview(ReviewModel review) async {
    await reviewsCollection.doc(review.id).set(review.toFirestore());
    // Update rating using advanced algorithm
    await updateUserRatingAdvanced(review.revieweeId);
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
  /// Uses simple average for backward compatibility.
  Future<void> updateUserAverageRating(String userId) async {
    final avg = await getAverageRating(userId);
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'rating': avg,
    });
  }

  /// Updates user rating using advanced algorithms (Bayesian + time-weighted).
  Future<void> updateUserRatingAdvanced(String userId) async {
    await RatingAlgorithmService.updateUserRatingAdvanced(userId);
  }

  /// Gets Bayesian average rating (handles low review counts better).
  Future<double> getBayesianAverageRating(String userId) async {
    final reviews = await getReviewsForUser(userId);
    return RatingAlgorithmService.calculateBayesianAverage(reviews);
  }

  /// Gets time-weighted average rating (prioritizes recent reviews).
  Future<double> getTimeWeightedAverageRating(String userId) async {
    final reviews = await getReviewsForUser(userId);
    return RatingAlgorithmService.calculateTimeWeightedAverage(reviews);
  }

  /// Gets confidence score based on review count.
  Future<double> getRatingConfidence(String userId) async {
    final reviews = await getReviewsForUser(userId);
    return RatingAlgorithmService.calculateConfidenceScore(reviews.length);
  }
} 
