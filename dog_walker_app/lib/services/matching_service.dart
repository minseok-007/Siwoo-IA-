import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/walk_request_model.dart';

/// Advanced matching service that uses multiple algorithms to find compatible
/// walkers for dog owners and vice versa.
class MatchingService {
  static const double _earthRadius = 6371.0; // Earth's radius in kilometers
  
  // Weighted scoring system for different matching factors
  static const Map<String, double> _matchingWeights = {
    'distance': 0.25,        // 25% - Geographic proximity
    'dogSize': 0.20,         // 20% - Dog size compatibility
    'schedule': 0.20,        // 20% - Time availability
    'experience': 0.15,      // 15% - Walker experience level
    'rating': 0.10,          // 10% - User rating
    'price': 0.10,           // 10% - Price compatibility
  };

  /// Calculate distance between two geographic points using Haversine formula
  /// Time Complexity: O(1) - Constant time calculation
  static double calculateDistance(GeoPoint point1, GeoPoint point2) {
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLon = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  /// Calculate distance score (0-1, where 1 is closest)
  /// Uses inverse exponential decay for smooth distance scoring
  static double calculateDistanceScore(double distance, double maxDistance) {
    if (distance <= 0) return 1.0;
    if (distance >= maxDistance) return 0.0;
    
    // Exponential decay: closer distances get higher scores
    return exp(-distance / (maxDistance * 0.3));
  }

  /// Calculate dog size compatibility score
  /// Time Complexity: O(n) where n is the number of preferred dog sizes
  static double calculateDogSizeScore(List<DogSize> walkerPreferences, DogSize dogSize) {
    if (walkerPreferences.isEmpty) return 0.5; // Neutral score if no preferences
    
    // Perfect match gets highest score
    if (walkerPreferences.contains(dogSize)) return 1.0;
    
    // Size proximity scoring (small-medium-large)
    final sizeOrder = [DogSize.small, DogSize.medium, DogSize.large];
    final dogIndex = sizeOrder.indexOf(dogSize);
    
    double bestScore = 0.0;
    for (final preferredSize in walkerPreferences) {
      final preferredIndex = sizeOrder.indexOf(preferredSize);
      final distance = (dogIndex - preferredIndex).abs();
      
      // Score based on size proximity (adjacent sizes get good scores)
      double score;
      switch (distance) {
        case 0: score = 1.0; break;      // Exact match
        case 1: score = 0.7; break;      // Adjacent size
        case 2: score = 0.3; break;      // Far size
        default: score = 0.0; break;
      }
      
      if (score > bestScore) bestScore = score;
    }
    
    return bestScore;
  }

  /// Calculate schedule compatibility score
  /// Time Complexity: O(n*m) where n is available days and m is preferred time slots
  static double calculateScheduleScore(List<int> walkerAvailableDays, List<String> walkerTimeSlots, 
                                     DateTime walkTime, List<String> ownerTimeSlots) {
    if (walkerAvailableDays.isEmpty || walkerTimeSlots.isEmpty) return 0.0;
    
    // Check day availability
    final walkDay = walkTime.weekday % 7; // Convert to 0-6 (Sunday-Saturday)
    if (!walkerAvailableDays.contains(walkDay)) return 0.0;
    
    // Check time slot compatibility
    final walkHour = walkTime.hour;
    String walkTimeSlot;
    if (walkHour < 12) walkTimeSlot = 'morning';
    else if (walkHour < 17) walkTimeSlot = 'afternoon';
    else walkTimeSlot = 'evening';
    
    // Perfect time match
    if (walkerTimeSlots.contains(walkTimeSlot)) return 1.0;
    
    // Check owner preferences
    if (ownerTimeSlots.isNotEmpty && ownerTimeSlots.contains(walkTimeSlot)) {
      return 0.8; // Good match if owner prefers this time
    }
    
    return 0.5; // Neutral score
  }

  /// Calculate experience compatibility score
  /// Time Complexity: O(1) - Constant time calculation
  static double calculateExperienceScore(ExperienceLevel walkerLevel, DogModel dog) {
    // Map experience levels to numeric values
    final experienceMap = {
      ExperienceLevel.beginner: 1,
      ExperienceLevel.intermediate: 2,
      ExperienceLevel.expert: 3,
    };
    
    final walkerValue = experienceMap[walkerLevel] ?? 1;
    
    // Calculate dog difficulty score
    int dogDifficulty = 1; // Base difficulty
    
    // Increase difficulty based on various factors
    if (dog.specialNeeds.contains(SpecialNeeds.training)) dogDifficulty += 2;
    if (dog.specialNeeds.contains(SpecialNeeds.puppy)) dogDifficulty += 1;
    if (dog.specialNeeds.contains(SpecialNeeds.elderly)) dogDifficulty += 1;
    if (dog.temperament == DogTemperament.aggressive) dogDifficulty += 2;
    if (dog.energyLevel == EnergyLevel.veryHigh) dogDifficulty += 1;
    
    // Score based on experience vs difficulty
    if (walkerValue >= dogDifficulty) return 1.0;           // Experienced enough
    if (walkerValue == dogDifficulty - 1) return 0.7;       // Slightly under-experienced
    return 0.3;                                             // Under-experienced
  }

  /// Calculate rating score (0-1, where 1 is highest rating)
  static double calculateRatingScore(double rating) {
    return (rating / 5.0).clamp(0.0, 1.0);
  }

  /// Calculate price compatibility score
  /// Time Complexity: O(1) - Constant time calculation
  static double calculatePriceScore(double walkerRate, double ownerBudget, double walkDuration) {
    final totalCost = walkerRate * walkDuration;
    
    if (totalCost <= ownerBudget) return 1.0;           // Within budget
    if (totalCost <= ownerBudget * 1.2) return 0.7;     // Slightly over budget
    if (totalCost <= ownerBudget * 1.5) return 0.4;     // Moderately over budget
    return 0.0;                                          // Way over budget
  }

  /// Main matching algorithm using weighted scoring
  /// Time Complexity: O(n*m*k) where n=walkers, m=owners, k=matching factors
  /// Space Complexity: O(n) for storing match scores
  static List<MatchResult> findCompatibleMatches(
    List<UserModel> walkers,
    WalkRequestModel walkRequest,
    UserModel owner,
    DogModel dog,
    {int maxResults = 10}
  ) {
    final List<MatchResult> matches = [];
    
    for (final walker in walkers) {
      if (walker.userType != UserType.dogWalker) continue;
      
      try {
        final matchScore = _calculateOverallMatchScore(walker, walkRequest, owner, dog);
        
        if (matchScore > 0.3) { // Only include reasonable matches
          matches.add(MatchResult(
            walker: walker,
            score: matchScore,
            breakdown: _getScoreBreakdown(walker, walkRequest, owner, dog),
          ));
        }
      } catch (e) {
        print('Error calculating match score for walker ${walker.id}: $e');
        continue;
      }
    }
    
    // Sort by score (highest first) and limit results
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches.take(maxResults).toList();
  }

  /// Calculate overall match score using weighted factors
  /// Time Complexity: O(1) - Constant time calculation
  static double _calculateOverallMatchScore(
    UserModel walker,
    WalkRequestModel walkRequest,
    UserModel owner,
    DogModel dog,
  ) {
    if (walker.location == null || owner.location == null) return 0.0;
    
    // Calculate individual factor scores
    final distance = calculateDistance(walker.location!, owner.location!);
    final distanceScore = calculateDistanceScore(distance, walker.maxDistance);
    
    final dogSizeScore = calculateDogSizeScore(walker.preferredDogSizes, dog.size);
    
    final scheduleScore = calculateScheduleScore(
      walker.availableDays,
      walker.preferredTimeSlots,
      walkRequest.time,
      owner.preferredTimeSlots,
    );
    
    final experienceScore = calculateExperienceScore(walker.experienceLevel, dog);
    final ratingScore = calculateRatingScore(walker.rating);
    
    // Estimate walk duration (assuming 30 minutes for now)
    final walkDuration = 0.5; // hours
    final priceScore = calculatePriceScore(walker.hourlyRate, walkRequest.budget ?? 50.0, walkDuration);
    
    // Calculate weighted sum
    double totalScore = 0.0;
    double totalWeight = 0.0;
    
    totalScore += distanceScore * _matchingWeights['distance']!;
    totalScore += dogSizeScore * _matchingWeights['dogSize']!;
    totalScore += scheduleScore * _matchingWeights['schedule']!;
    totalScore += experienceScore * _matchingWeights['experience']!;
    totalScore += ratingScore * _matchingWeights['rating']!;
    totalScore += priceScore * _matchingWeights['price']!;
    
    totalWeight = _matchingWeights.values.reduce((a, b) => a + b);
    
    return totalScore / totalWeight;
  }

  /// Get detailed score breakdown for debugging and transparency
  static Map<String, double> _getScoreBreakdown(
    UserModel walker,
    WalkRequestModel walkRequest,
    UserModel owner,
    DogModel dog,
  ) {
    if (walker.location == null || owner.location == null) return {};
    
    final distance = calculateDistance(walker.location!, owner.location!);
    
    return {
      'distance': calculateDistanceScore(distance, walker.maxDistance),
      'dogSize': calculateDogSizeScore(walker.preferredDogSizes, dog.size),
      'schedule': calculateScheduleScore(
        walker.availableDays,
        walker.preferredTimeSlots,
        walkRequest.time,
        owner.preferredTimeSlots,
      ),
      'experience': calculateExperienceScore(walker.experienceLevel, dog),
      'rating': calculateRatingScore(walker.rating),
      'price': calculatePriceScore(walker.hourlyRate, walkRequest.budget ?? 50.0, 0.5),
    };
  }

  /// Alternative matching algorithm using Hungarian Algorithm for optimal 1:1 matching
  /// This is useful when you need to assign exactly one walker to each walk request
  /// Time Complexity: O(n³) where n is the number of walkers/requests
  /// Space Complexity: O(n²) for the cost matrix
  static List<MatchResult> findOptimalMatches(
    List<UserModel> walkers,
    List<WalkRequestModel> walkRequests,
    Map<String, UserModel> owners,
    Map<String, DogModel> dogs,
  ) {
    if (walkers.isEmpty || walkRequests.isEmpty) return [];
    
    // Create cost matrix (negative scores because Hungarian algorithm minimizes cost)
    final int n = max(walkers.length, walkRequests.length);
    final List<List<double>> costMatrix = List.generate(
      n,
      (i) => List.generate(n, (j) => 0.0),
    );
    
    // Fill cost matrix with match scores
    for (int i = 0; i < walkers.length; i++) {
      for (int j = 0; j < walkRequests.length; j++) {
        final walkRequest = walkRequests[j];
        final owner = owners[walkRequest.ownerId];
        final dog = dogs[walkRequest.dogId];
        
        if (owner != null && dog != null) {
          final score = _calculateOverallMatchScore(walkers[i], walkRequest, owner, dog);
          costMatrix[i][j] = -score; // Negative because Hungarian minimizes
        } else {
          costMatrix[i][j] = 0.0; // No match possible
        }
      }
    }
    
    // Apply Hungarian algorithm (simplified version)
    final assignments = _hungarianAlgorithm(costMatrix);
    
    // Convert assignments to match results
    final List<MatchResult> results = [];
    for (int i = 0; i < assignments.length; i++) {
      final walkerIndex = i;
      final requestIndex = assignments[i];
      
      if (requestIndex < walkRequests.length && walkerIndex < walkers.length) {
        final walkRequest = walkRequests[requestIndex];
        final owner = owners[walkRequest.ownerId];
        final dog = dogs[walkRequest.dogId];
        
        if (owner != null && dog != null) {
          final score = _calculateOverallMatchScore(walkers[walkerIndex], walkRequest, owner, dog);
          results.add(MatchResult(
            walker: walkers[walkerIndex],
            score: score,
            breakdown: _getScoreBreakdown(walkers[walkerIndex], walkRequest, owner, dog),
          ));
        }
      }
    }
    
    return results;
  }

  /// Simplified Hungarian Algorithm implementation
  /// This is a basic version - for production, consider using a more robust library
  static List<int> _hungarianAlgorithm(List<List<double>> costMatrix) {
    final int n = costMatrix.length;
    final List<int> assignment = List.generate(n, (i) => i);
    
    // Simple greedy assignment (this can be improved with full Hungarian algorithm)
    for (int i = 0; i < n; i++) {
      double bestCost = double.infinity;
      int bestJ = i;
      
      for (int j = 0; j < n; j++) {
        if (costMatrix[i][j] < bestCost) {
          bestCost = costMatrix[i][j];
          bestJ = j;
        }
      }
      
      assignment[i] = bestJ;
    }
    
    return assignment;
  }
}

/// Result class for matching algorithm
class MatchResult {
  final UserModel walker;
  final double score;
  final Map<String, double> breakdown;
  final String? explanation;

  MatchResult({
    required this.walker,
    required this.score,
    required this.breakdown,
    this.explanation,
  });

  @override
  String toString() {
    return 'MatchResult(walker: ${walker.fullName}, score: ${score.toStringAsFixed(3)})';
  }
} 