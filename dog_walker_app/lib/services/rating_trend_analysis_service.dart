import 'dart:math';
import '../models/review_model.dart';

/// Sliding Window algorithm for analyzing rating trends over time.
/// 
/// Implements efficient computation of moving averages and trend detection
/// using sliding window technique.
/// 
/// Time Complexity: O(n) where n is the number of reviews
/// Space Complexity: O(windowSize)
class RatingTrendAnalysisService {
  /// Calculates moving average of ratings using sliding window.
  /// 
  /// Algorithm:
  /// - Maintain a window of the last N reviews
  /// - As we iterate through reviews, add new ones and remove old ones
  /// - Calculate average for each window position
  /// 
  /// Returns list of (date, averageRating) pairs for each window position.
  static List<({DateTime date, double average})> calculateMovingAverage(
    List<ReviewModel> reviews, {
    int windowSize = 10,
  }) {
    if (reviews.isEmpty) return [];

    // Sort reviews by date (oldest first)
    final sorted = List<ReviewModel>.from(reviews)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final result = <({DateTime date, double average})>[];
    final window = <ReviewModel>[];
    double windowSum = 0.0;

    for (final review in sorted) {
      window.add(review);
      windowSum += review.rating;

      // If window is full, remove oldest and calculate average
      if (window.length > windowSize) {
        final oldest = window.removeAt(0);
        windowSum -= oldest.rating;
      }

      // Calculate average for current window
      if (window.length >= windowSize) {
        final average = windowSum / window.length;
        result.add((date: review.timestamp, average: average));
      }
    }

    return result;
  }

  /// Detects rating trend (improving, declining, stable) using linear regression.
  /// 
  /// Algorithm:
  /// - Use least squares method to fit a line through recent ratings
  /// - Calculate slope to determine trend direction
  /// - Slope > threshold: improving
  /// - Slope < -threshold: declining
  /// - Otherwise: stable
  /// 
  /// Time Complexity: O(n) where n is windowSize
  static RatingTrend detectTrend(
    List<ReviewModel> reviews, {
    int windowSize = 20,
    double threshold = 0.1,
  }) {
    if (reviews.length < windowSize) {
      return RatingTrend.stable; // Not enough data
    }

    // Get most recent reviews
    final sorted = List<ReviewModel>.from(reviews)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final recent = sorted.take(windowSize).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Linear regression: y = mx + b
    // x = days since first review, y = rating
    final n = recent.length;
    final firstDate = recent.first.timestamp;
    
    double sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;

    for (int i = 0; i < n; i++) {
      final daysSinceFirst = recent[i].timestamp.difference(firstDate).inDays.toDouble();
      final rating = recent[i].rating;
      
      sumX += daysSinceFirst;
      sumY += rating;
      sumXY += daysSinceFirst * rating;
      sumX2 += daysSinceFirst * daysSinceFirst;
    }

    // Calculate slope: m = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 1e-10) {
      return RatingTrend.stable; // No variation in time
    }

    final slope = (n * sumXY - sumX * sumY) / denominator;

    if (slope > threshold) {
      return RatingTrend.improving;
    } else if (slope < -threshold) {
      return RatingTrend.declining;
    } else {
      return RatingTrend.stable;
    }
  }

  /// Finds maximum rating drop/rise in a sliding window.
  /// 
  /// Problem: Find the maximum difference between any two points
  /// in a time series where the later point is higher/lower.
  /// 
  /// This is similar to "Best Time to Buy and Sell Stock" problem.
  /// 
  /// Time Complexity: O(n)
  /// Space Complexity: O(1)
  static ({double maxDrop, double maxRise, DateTime? dropStart, DateTime? riseStart}) 
      findMaxChange(List<ReviewModel> reviews) {
    if (reviews.length < 2) {
      return (maxDrop: 0.0, maxRise: 0.0, dropStart: null, riseStart: null);
    }

    final sorted = List<ReviewModel>.from(reviews)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double maxDrop = 0.0;
    double maxRise = 0.0;
    DateTime? dropStart;
    DateTime? riseStart;
    
    double minRating = sorted.first.rating;
    double maxRating = sorted.first.rating;
    DateTime? minDate = sorted.first.timestamp;
    DateTime? maxDate = sorted.first.timestamp;

    for (int i = 1; i < sorted.length; i++) {
      final currentRating = sorted[i].rating;
      final currentDate = sorted[i].timestamp;

      // Track maximum drop (highest to lowest)
      if (currentRating < minRating) {
        minRating = currentRating;
        minDate = currentDate;
      } else {
        final drop = maxRating - currentRating;
        if (drop > maxDrop) {
          maxDrop = drop;
          dropStart = maxDate;
        }
      }

      // Track maximum rise (lowest to highest)
      if (currentRating > maxRating) {
        maxRating = currentRating;
        maxDate = currentDate;
      } else {
        final rise = currentRating - minRating;
        if (rise > maxRise) {
          maxRise = rise;
          riseStart = minDate;
        }
      }
    }

    return (
      maxDrop: maxDrop,
      maxRise: maxRise,
      dropStart: dropStart,
      riseStart: riseStart,
    );
  }

  /// Calculates rating volatility (standard deviation) using sliding window.
  /// 
  /// Higher volatility = more inconsistent ratings.
  static double calculateVolatility(
    List<ReviewModel> reviews, {
    int windowSize = 10,
  }) {
    if (reviews.length < windowSize) return 0.0;

    final sorted = List<ReviewModel>.from(reviews)
      ..sort((a, b) => b.timestamp.compareTo(b.timestamp));
    
    final recent = sorted.take(windowSize).toList();
    
    final mean = recent.fold(0.0, (sum, r) => sum + r.rating) / recent.length;
    
    final variance = recent.fold(0.0, (sum, r) {
      final diff = r.rating - mean;
      return sum + diff * diff;
    }) / recent.length;

    return sqrt(variance); // Standard deviation
  }
}

enum RatingTrend {
  improving,
  declining,
  stable,
}
