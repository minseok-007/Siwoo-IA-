import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
import 'review_service.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

/// Advanced rating calculation algorithms for review systems.
/// - Implements Bayesian average to handle low review counts
/// - Implements time-weighted average to prioritize recent reviews
/// - Calculates confidence scores based on review volume
class RatingAlgorithmService {
  // Bayesian prior: assume average rating of 3.5 with confidence equivalent to 10 reviews
  static const double _bayesianPriorMean = 3.5;
  static const int _bayesianPriorCount = 10;

  /// Calculates Bayesian average rating.
  /// 
  /// Formula: (priorMean * priorCount + sum(ratings)) / (priorCount + reviewCount)
  /// 
  /// This prevents users with few reviews from having extreme ratings.
  /// Users need more reviews to move significantly away from the prior mean.
  /// 
  /// Time Complexity: O(n) where n is the number of reviews
  /// Space Complexity: O(1)
  static double calculateBayesianAverage(List<ReviewModel> reviews) {
    if (reviews.isEmpty) return _bayesianPriorMean;

    final reviewCount = reviews.length;
    final sumRatings = reviews.fold(0.0, (sum, review) => sum + review.rating);

    final numerator = (_bayesianPriorMean * _bayesianPriorCount) + sumRatings;
    final denominator = _bayesianPriorCount + reviewCount;

    return numerator / denominator;
  }

  /// Calculates time-weighted average rating.
  /// 
  /// Recent reviews have exponentially higher weight than older reviews.
  /// Weight decay factor: reviews older than 30 days have reduced weight.
  /// 
  /// Formula: sum(rating * weight) / sum(weight)
  /// where weight = exp(-daysSinceReview / decayFactor)
  /// 
  /// Time Complexity: O(n) where n is the number of reviews
  /// Space Complexity: O(1)
  static double calculateTimeWeightedAverage(
    List<ReviewModel> reviews, {
    double decayFactor = 30.0, // Reviews older than 30 days have significantly reduced weight
  }) {
    if (reviews.isEmpty) return 0.0;

    final now = DateTime.now();
    double weightedSum = 0.0;
    double totalWeight = 0.0;

    for (final review in reviews) {
      final daysSinceReview = now.difference(review.timestamp).inDays.toDouble();
      
      // Exponential decay: weight = exp(-days / decayFactor)
      // Recent reviews (0 days) have weight = 1.0
      // Reviews after decayFactor days have weight ≈ 0.368
      final weight = exp(-daysSinceReview / decayFactor);
      
      weightedSum += review.rating * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }

  /// Calculates confidence score (0.0 to 1.0) based on review count.
  /// 
  /// Uses logarithmic scaling: confidence increases quickly with first few reviews,
  /// then levels off. Formula: 1 - exp(-reviewCount / scaleFactor)
  /// 
  /// - 1 review: ~0.18 confidence
  /// - 5 reviews: ~0.63 confidence
  /// - 10 reviews: ~0.86 confidence
  /// - 20+ reviews: >0.95 confidence
  /// 
  /// Time Complexity: O(1)
  static double calculateConfidenceScore(int reviewCount, {double scaleFactor = 5.0}) {
    if (reviewCount <= 0) return 0.0;
    return (1.0 - exp(-reviewCount / scaleFactor)).clamp(0.0, 1.0);
  }

  /// Calculates combined rating using both Bayesian average and time-weighted average.
  /// 
  /// Combines both algorithms with configurable weights:
  /// - Bayesian average provides stability for low review counts
  /// - Time-weighted average reflects recent performance
  /// 
  /// Time Complexity: O(n) where n is the number of reviews
  static double calculateCombinedRating(
    List<ReviewModel> reviews, {
    double bayesianWeight = 0.4,
    double timeWeightedWeight = 0.6,
  }) {
    if (reviews.isEmpty) return _bayesianPriorMean;

    final bayesianAvg = calculateBayesianAverage(reviews);
    final timeWeightedAvg = calculateTimeWeightedAverage(reviews);

    // Normalize weights
    final totalWeight = bayesianWeight + timeWeightedWeight;
    final normalizedBayesianWeight = bayesianWeight / totalWeight;
    final normalizedTimeWeightedWeight = timeWeightedWeight / totalWeight;

    return (bayesianAvg * normalizedBayesianWeight) +
           (timeWeightedAvg * normalizedTimeWeightedWeight);
  }

  /// Updates user rating using advanced algorithms.
  /// 
  /// Calculates combined rating and confidence score, then updates Firestore.
  static Future<void> updateUserRatingAdvanced(String userId) async {
    final reviewService = ReviewService();
    final reviews = await reviewService.getReviewsForUser(userId);

    if (reviews.isEmpty) {
      // No reviews: use Bayesian prior
      await _firestore.collection('users').doc(userId).update({
        'rating': _bayesianPriorMean,
        'ratingConfidence': 0.0,
      });
      return;
    }

    final combinedRating = calculateCombinedRating(reviews);
    final confidence = calculateConfidenceScore(reviews.length);

    await _firestore.collection('users').doc(userId).update({
      'rating': combinedRating,
      'ratingConfidence': confidence,
    });
  }
}
