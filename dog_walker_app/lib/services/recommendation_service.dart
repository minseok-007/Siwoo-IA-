import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/review_model.dart';
import '../models/walk_request_model.dart';
import 'review_service.dart';
import 'walk_request_service.dart';

/// Collaborative Filtering Recommendation Service
/// 
/// Implements user-based collaborative filtering algorithm:
/// - Finds users with similar preferences/ratings
/// - Recommends walkers/owners based on similar users' preferences
/// 
/// Algorithm:
/// 1. Build user-item rating matrix
/// 2. Calculate cosine similarity between users
/// 3. Find k-nearest neighbors
/// 4. Generate recommendations using weighted average
/// 
/// Time Complexity: O(n² × m) where n = users, m = items
/// Space Complexity: O(n × m) for rating matrix
class RecommendationService {
  final ReviewService _reviewService = ReviewService();
  final WalkRequestService _walkRequestService = WalkRequestService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recommends walkers for an owner based on collaborative filtering.
  /// 
  /// Uses cosine similarity to find owners with similar preferences,
  /// then recommends walkers that similar owners rated highly.
  /// 
  /// Time Complexity: O(n² × m) where n = owners, m = walkers
  /// Space Complexity: O(n × m)
  Future<List<RecommendationResult>> recommendWalkersForOwner({
    required String ownerId,
    required List<UserModel> allWalkers,
    int kNeighbors = 5,
    int maxRecommendations = 10,
  }) async {
    // Step 1: Get all reviews to build rating matrix
    final allReviews = await _getAllReviews();
    
    // Step 2: Build user-item rating matrix
    // Matrix[ownerId][walkerId] = average rating
    final ratingMatrix = _buildRatingMatrix(allReviews);
    
    // Step 3: Calculate similarity between current owner and all other owners
    final similarities = _calculateUserSimilarities(
      ownerId,
      ratingMatrix,
      allReviews,
    );
    
    // Step 4: Find k-nearest neighbors (most similar owners)
    final neighbors = _findKNearestNeighbors(similarities, kNeighbors);
    
    // Step 5: Generate recommendations using weighted average
    final recommendations = _generateRecommendations(
      ownerId,
      neighbors,
      ratingMatrix,
      allWalkers,
      maxRecommendations,
    );
    
    return recommendations;
  }

  /// Recommends walk requests for a walker based on collaborative filtering.
  /// 
  /// Finds walkers with similar preferences and recommends requests
  /// that similar walkers accepted/highly rated.
  /// 
  /// Time Complexity: O(n² × m) where n = walkers, m = requests
  /// Space Complexity: O(n × m)
  Future<List<WalkRequestRecommendation>> recommendWalkRequestsForWalker({
    required String walkerId,
    required List<WalkRequestModel> availableRequests,
    int kNeighbors = 5,
    int maxRecommendations = 10,
  }) async {
    // Get all walk applications (implicit ratings: accepted = high rating)
    final allApplications = await _getAllApplications();
    
    // Build walker-request preference matrix
    final preferenceMatrix = _buildPreferenceMatrix(allApplications);
    
    // Calculate similarity with other walkers
    final similarities = _calculateWalkerSimilarities(
      walkerId,
      preferenceMatrix,
      allApplications,
    );
    
    // Find k-nearest neighbors
    final neighbors = _findKNearestNeighbors(similarities, kNeighbors);
    
    // Generate recommendations
    final recommendations = _generateWalkRequestRecommendations(
      walkerId,
      neighbors,
      preferenceMatrix,
      availableRequests,
      maxRecommendations,
    );
    
    return recommendations;
  }

  /// Builds a user-item rating matrix from reviews.
  /// 
  /// Matrix structure: Map<ownerId, Map<walkerId, averageRating>>
  /// 
  /// Time Complexity: O(r) where r = number of reviews
  /// Space Complexity: O(n × m) where n = owners, m = walkers
  Map<String, Map<String, double>> _buildRatingMatrix(
    List<ReviewModel> reviews,
  ) {
    final matrix = <String, Map<String, double>>{};
    final ratingSums = <String, Map<String, List<double>>>{};
    
    // Aggregate ratings by owner-walker pairs
    for (final review in reviews) {
      // Owner reviewing walker
      if (!ratingSums.containsKey(review.reviewerId)) {
        ratingSums[review.reviewerId] = {};
      }
      if (!ratingSums[review.reviewerId]!.containsKey(review.revieweeId)) {
        ratingSums[review.reviewerId]![review.revieweeId] = [];
      }
      ratingSums[review.reviewerId]![review.revieweeId]!.add(review.rating);
    }
    
    // Calculate averages
    for (final ownerId in ratingSums.keys) {
      matrix[ownerId] = {};
      for (final walkerId in ratingSums[ownerId]!.keys) {
        final ratings = ratingSums[ownerId]![walkerId]!;
        matrix[ownerId]![walkerId] = ratings.reduce((a, b) => a + b) / ratings.length;
      }
    }
    
    return matrix;
  }

  /// Calculates cosine similarity between users.
  /// 
  /// Cosine Similarity = (A · B) / (||A|| × ||B||)
  /// 
  /// Time Complexity: O(m) where m = number of common items
  /// Space Complexity: O(1)
  double _calculateCosineSimilarity(
    Map<String, double> ratings1,
    Map<String, double> ratings2,
  ) {
    // Find common items (walkers both users rated)
    final commonItems = ratings1.keys
        .where((key) => ratings2.containsKey(key))
        .toList();
    
    if (commonItems.isEmpty) return 0.0;
    
    // Calculate dot product and magnitudes
    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;
    
    for (final item in commonItems) {
      final rating1 = ratings1[item]!;
      final rating2 = ratings2[item]!;
      
      dotProduct += rating1 * rating2;
      magnitude1 += rating1 * rating1;
      magnitude2 += rating2 * rating2;
    }
    
    if (magnitude1 == 0.0 || magnitude2 == 0.0) return 0.0;
    
    return dotProduct / (sqrt(magnitude1) * sqrt(magnitude2));
  }

  /// Calculates similarity between current owner and all other owners.
  /// 
  /// Time Complexity: O(n × m) where n = owners, m = walkers
  /// Space Complexity: O(n)
  Map<String, double> _calculateUserSimilarities(
    String ownerId,
    Map<String, Map<String, double>> ratingMatrix,
    List<ReviewModel> reviews,
  ) {
    final similarities = <String, double>{};
    final ownerRatings = ratingMatrix[ownerId] ?? {};
    
    if (ownerRatings.isEmpty) return similarities;
    
    for (final otherOwnerId in ratingMatrix.keys) {
      if (otherOwnerId == ownerId) continue;
      
      final otherRatings = ratingMatrix[otherOwnerId] ?? {};
      if (otherRatings.isEmpty) continue;
      
      final similarity = _calculateCosineSimilarity(ownerRatings, otherRatings);
      if (similarity > 0.0) {
        similarities[otherOwnerId] = similarity;
      }
    }
    
    return similarities;
  }

  /// Calculates similarity between walkers based on accepted requests.
  /// 
  /// Uses Jaccard similarity: intersection / union of accepted requests
  /// 
  /// Time Complexity: O(n × m) where n = walkers, m = requests
  /// Space Complexity: O(n)
  Map<String, double> _calculateWalkerSimilarities(
    String walkerId,
    Map<String, Set<String>> preferenceMatrix,
    List<Map<String, dynamic>> applications,
  ) {
    final similarities = <String, double>{};
    final walkerRequests = preferenceMatrix[walkerId] ?? {};
    
    if (walkerRequests.isEmpty) return similarities;
    
    for (final otherWalkerId in preferenceMatrix.keys) {
      if (otherWalkerId == walkerId) continue;
      
      final otherRequests = preferenceMatrix[otherWalkerId] ?? {};
      if (otherRequests.isEmpty) continue;
      
      // Jaccard similarity
      final intersection = walkerRequests.intersection(otherRequests).length;
      final union = walkerRequests.union(otherRequests).length;
      
      if (union > 0) {
        final similarity = intersection / union;
        if (similarity > 0.0) {
          similarities[otherWalkerId] = similarity;
        }
      }
    }
    
    return similarities;
  }

  /// Finds k-nearest neighbors (most similar users).
  /// 
  /// Time Complexity: O(n log n) for sorting
  /// Space Complexity: O(k)
  List<({String userId, double similarity})> _findKNearestNeighbors(
    Map<String, double> similarities,
    int k,
  ) {
    final sorted = similarities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sorted
        .take(k)
        .map((e) => (userId: e.key, similarity: e.value))
        .toList();
  }

  /// Generates recommendations using weighted average of neighbors' ratings.
  /// 
  /// Predicted Rating = Σ(similarity × rating) / Σ(similarity)
  /// 
  /// Time Complexity: O(k × m) where k = neighbors, m = items
  /// Space Complexity: O(m)
  List<RecommendationResult> _generateRecommendations(
    String ownerId,
    List<({String userId, double similarity})> neighbors,
    Map<String, Map<String, double>> ratingMatrix,
    List<UserModel> allWalkers,
    int maxRecommendations,
  ) {
    final ownerRatings = ratingMatrix[ownerId] ?? {};
    final predictedRatings = <String, ({double score, double confidence})>{};
    
    // For each walker not yet rated by owner
    for (final walker in allWalkers) {
      if (ownerRatings.containsKey(walker.id)) continue;
      
      double weightedSum = 0.0;
      double similaritySum = 0.0;
      
      // Calculate weighted average from neighbors
      for (final neighbor in neighbors) {
        final neighborRatings = ratingMatrix[neighbor.userId] ?? {};
        final neighborRating = neighborRatings[walker.id];
        
        if (neighborRating != null) {
          weightedSum += neighbor.similarity * neighborRating;
          similaritySum += neighbor.similarity;
        }
      }
      
      if (similaritySum > 0.0) {
        final predictedRating = weightedSum / similaritySum;
        final confidence = similaritySum / neighbors.length; // Normalize confidence
        predictedRatings[walker.id] = (
          score: predictedRating,
          confidence: confidence,
        );
      }
    }
    
    // Sort by predicted rating and confidence
    final sorted = predictedRatings.entries.toList()
      ..sort((a, b) {
        final scoreCompare = b.value.score.compareTo(a.value.score);
        if (scoreCompare != 0) return scoreCompare;
        return b.value.confidence.compareTo(a.value.confidence);
      });
    
    final recommendations = <RecommendationResult>[];
    for (final entry in sorted.take(maxRecommendations)) {
      final walker = allWalkers.firstWhere(
        (w) => w.id == entry.key,
        orElse: () => allWalkers.first,
      );
      
      recommendations.add(
        RecommendationResult(
          user: walker,
          predictedRating: entry.value.score,
          confidence: entry.value.confidence,
          reason: 'Recommended by ${neighbors.length} similar owners',
        ),
      );
    }
    
    return recommendations;
  }

  /// Generates walk request recommendations for walker.
  /// 
  /// Time Complexity: O(k × m) where k = neighbors, m = requests
  /// Space Complexity: O(m)
  List<WalkRequestRecommendation> _generateWalkRequestRecommendations(
    String walkerId,
    List<({String userId, double similarity})> neighbors,
    Map<String, Set<String>> preferenceMatrix,
    List<WalkRequestModel> availableRequests,
    int maxRecommendations,
  ) {
    final walkerRequests = preferenceMatrix[walkerId] ?? {};
    final recommendationScores = <String, double>{};
    
    // For each available request
    for (final request in availableRequests) {
      if (walkerRequests.contains(request.id)) continue;
      
      double score = 0.0;
      int count = 0;
      
      // Count how many similar walkers accepted this request
      for (final neighbor in neighbors) {
        final neighborRequests = preferenceMatrix[neighbor.userId] ?? {};
        if (neighborRequests.contains(request.id)) {
          score += neighbor.similarity;
          count++;
        }
      }
      
      if (count > 0) {
        // Weighted score: similarity × acceptance rate
        recommendationScores[request.id] = score / neighbors.length;
      }
    }
    
    // Sort by score
    final sorted = recommendationScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final recommendations = <WalkRequestRecommendation>[];
    for (final entry in sorted.take(maxRecommendations)) {
      final request = availableRequests.firstWhere(
        (r) => r.id == entry.key,
      );
      
      recommendations.add(
        WalkRequestRecommendation(
          walkRequest: request,
          recommendationScore: entry.value,
          reason: '${neighbors.length} similar walkers accepted this request',
        ),
      );
    }
    
    return recommendations;
  }

  /// Builds preference matrix from walk applications.
  /// 
  /// Matrix structure: Map<walkerId, Set<requestId>>
  /// 
  /// Time Complexity: O(a) where a = number of applications
  /// Space Complexity: O(n × m)
  Map<String, Set<String>> _buildPreferenceMatrix(
    List<Map<String, dynamic>> applications,
  ) {
    final matrix = <String, Set<String>>{};
    
    for (final app in applications) {
      final walkerId = app['walkerId'] as String;
      final requestId = app['walkRequestId'] as String;
      final status = app['status'] as String;
      
      // Only count accepted applications as positive preferences
      if (status == 'accepted') {
        if (!matrix.containsKey(walkerId)) {
          matrix[walkerId] = {};
        }
        matrix[walkerId]!.add(requestId);
      }
    }
    
    return matrix;
  }

  /// Gets all reviews from database.
  /// 
  /// Time Complexity: O(r) where r = number of reviews
  /// Space Complexity: O(r)
  Future<List<ReviewModel>> _getAllReviews() async {
    try {
      final query = await _firestore.collection('reviews').get();
      return query.docs
          .map((doc) => ReviewModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  /// Gets all walk applications from database.
  /// 
  /// Time Complexity: O(a) where a = number of applications
  /// Space Complexity: O(a)
  Future<List<Map<String, dynamic>>> _getAllApplications() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('walk_applications')
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'walkerId': data['walkerId'] ?? '',
          'walkRequestId': data['walkRequestId'] ?? '',
          'status': data['status'] ?? 'pending',
        };
      }).toList();
    } catch (e) {
      print('Error fetching applications: $e');
      return [];
    }
  }
}

/// Result of walker recommendation
class RecommendationResult {
  final UserModel user;
  final double predictedRating; // Predicted rating (0-5)
  final double confidence; // Confidence in prediction (0-1)
  final String reason; // Explanation for recommendation

  RecommendationResult({
    required this.user,
    required this.predictedRating,
    required this.confidence,
    required this.reason,
  });

  @override
  String toString() {
    return 'RecommendationResult(user: ${user.fullName}, rating: ${predictedRating.toStringAsFixed(2)}, confidence: ${confidence.toStringAsFixed(2)})';
  }
}

/// Result of walk request recommendation
class WalkRequestRecommendation {
  final WalkRequestModel walkRequest;
  final double recommendationScore; // Recommendation score (0-1)
  final String reason; // Explanation for recommendation

  WalkRequestRecommendation({
    required this.walkRequest,
    required this.recommendationScore,
    required this.reason,
  });

  @override
  String toString() {
    return 'WalkRequestRecommendation(request: ${walkRequest.id}, score: ${recommendationScore.toStringAsFixed(2)})';
  }
}
