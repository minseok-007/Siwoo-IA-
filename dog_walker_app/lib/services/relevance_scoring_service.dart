import 'dart:math';
import '../models/walk_request_model.dart';
import '../models/dog_model.dart';
import '../models/user_model.dart';
import '../models/dog_traits.dart';

/// Service for calculating relevance scores for walk requests based on walker preferences.
/// - Implements a multi-factor scoring algorithm that considers walker preferences, dog attributes, and time compatibility.
class RelevanceScoringService {
  // Weight configuration for different relevance factors
  static const Map<String, double> _relevanceWeights = {
    'preferredSize': 0.25,
    'preferredTemperament': 0.20,
    'preferredEnergyLevel': 0.15,
    'supportedSpecialNeeds': 0.15,
    'timeCompatibility': 0.15,
    'urgency': 0.10, // How soon the walk is scheduled
  };

  /// Calculates a relevance score (0.0 to 1.0) for a walk request based on walker preferences.
  /// 
  /// The algorithm considers:
  /// - Dog size compatibility with walker's preferred sizes
  /// - Dog temperament matching walker's comfort levels
  /// - Energy level alignment with walker's preferences
  /// - Special needs support capability
  /// - Time slot compatibility with walker's availability
  /// - Urgency factor (sooner walks get slight boost)
  /// 
  /// Time Complexity: O(1) for each request
  /// Space Complexity: O(1)
  static double calculateRelevanceScore({
    required WalkRequestModel walkRequest,
    required DogModel dog,
    required UserModel walker,
  }) {
    double totalScore = 0.0;
    double totalWeight = 0.0;

    // Size compatibility score
    final sizeScore = _calculateSizeCompatibilityScore(
      walker.preferredDogSizes,
      dog.size,
    );
    totalScore += sizeScore * _relevanceWeights['preferredSize']!;
    totalWeight += _relevanceWeights['preferredSize']!;

    // Temperament compatibility score
    final temperamentScore = _calculateTemperamentCompatibilityScore(
      walker.preferredTemperaments,
      dog.temperament,
    );
    totalScore += temperamentScore * _relevanceWeights['preferredTemperament']!;
    totalWeight += _relevanceWeights['preferredTemperament']!;

    // Energy level compatibility score
    final energyScore = _calculateEnergyCompatibilityScore(
      walker.preferredEnergyLevels,
      dog.energyLevel,
    );
    totalScore += energyScore * _relevanceWeights['preferredEnergyLevel']!;
    totalWeight += _relevanceWeights['preferredEnergyLevel']!;

    // Special needs support score
    final specialNeedsScore = _calculateSpecialNeedsSupportScore(
      walker.supportedSpecialNeeds,
      dog.specialNeeds,
    );
    totalScore += specialNeedsScore * _relevanceWeights['supportedSpecialNeeds']!;
    totalWeight += _relevanceWeights['supportedSpecialNeeds']!;

    // Time compatibility score
    final timeScore = _calculateTimeCompatibilityScore(
      walkRequest.startTime,
      walker.availableDays,
      walker.preferredTimeSlots,
    );
    totalScore += timeScore * _relevanceWeights['timeCompatibility']!;
    totalWeight += _relevanceWeights['timeCompatibility']!;

    // Urgency score (sooner walks get slight boost)
    final urgencyScore = _calculateUrgencyScore(walkRequest.startTime);
    totalScore += urgencyScore * _relevanceWeights['urgency']!;
    totalWeight += _relevanceWeights['urgency']!;

    // Normalize by total weight
    return totalWeight > 0 ? (totalScore / totalWeight).clamp(0.0, 1.0) : 0.0;
  }

  /// Size compatibility: exact match = 1.0, adjacent sizes = 0.7, far = 0.3
  static double _calculateSizeCompatibilityScore(
    List<DogSize> walkerPreferences,
    DogSize dogSize,
  ) {
    if (walkerPreferences.isEmpty) return 0.5; // Neutral if no preference

    if (walkerPreferences.contains(dogSize)) return 1.0;

    const sizeOrder = [DogSize.small, DogSize.medium, DogSize.large];
    final dogIndex = sizeOrder.indexOf(dogSize);

    double bestScore = 0.0;
    for (final preferredSize in walkerPreferences) {
      final preferredIndex = sizeOrder.indexOf(preferredSize);
      final distance = (dogIndex - preferredIndex).abs();

      double score;
      switch (distance) {
        case 0:
          score = 1.0; // Exact match
          break;
        case 1:
          score = 0.7; // Adjacent size
          break;
        case 2:
          score = 0.3; // Far size
          break;
        default:
          score = 0.0;
          break;
      }

      if (score > bestScore) bestScore = score;
    }

    return bestScore;
  }

  /// Temperament compatibility: exact match = 1.0, mismatch = 0.2
  static double _calculateTemperamentCompatibilityScore(
    List<DogTemperament> walkerPreferences,
    DogTemperament dogTemperament,
  ) {
    if (walkerPreferences.isEmpty) return 0.6; // Neutral baseline
    return walkerPreferences.contains(dogTemperament) ? 1.0 : 0.2;
  }

  /// Energy level compatibility: exact match = 1.0, adjacent = 0.7, far = 0.2
  static double _calculateEnergyCompatibilityScore(
    List<EnergyLevel> walkerPreferences,
    EnergyLevel dogEnergy,
  ) {
    if (walkerPreferences.isEmpty) return 0.6;

    if (walkerPreferences.contains(dogEnergy)) return 1.0;

    const order = [
      EnergyLevel.low,
      EnergyLevel.medium,
      EnergyLevel.high,
      EnergyLevel.veryHigh,
    ];
    final dogIndex = order.indexOf(dogEnergy);
    double bestScore = 0.2;

    for (final pref in walkerPreferences) {
      final distance = (order.indexOf(pref) - dogIndex).abs();
      if (distance == 1) {
        bestScore = max(bestScore, 0.7); // Adjacent level
      }
    }

    return bestScore;
  }

  /// Special needs support: percentage of dog's needs that walker can support
  static double _calculateSpecialNeedsSupportScore(
    List<SpecialNeeds> walkerSupported,
    List<SpecialNeeds> dogNeeds,
  ) {
    if (dogNeeds.isEmpty || dogNeeds.contains(SpecialNeeds.none)) {
      return 1.0; // No special needs required
    }
    if (walkerSupported.isEmpty) return 0.4;

    final matches = dogNeeds
        .where((need) => walkerSupported.contains(need))
        .length;
    return matches / dogNeeds.length;
  }

  /// Time compatibility: checks if walk time matches walker's availability
  static double _calculateTimeCompatibilityScore(
    DateTime walkTime,
    List<int> walkerAvailableDays,
    List<String> walkerTimeSlots,
  ) {
    if (walkerAvailableDays.isEmpty || walkerTimeSlots.isEmpty) return 0.5;

    // Check day availability
    final walkDay = walkTime.weekday % 7;
    if (!walkerAvailableDays.contains(walkDay)) return 0.0;

    // Check time slot compatibility
    final walkHour = walkTime.hour;
    String walkTimeSlot;
    if (walkHour < 12) {
      walkTimeSlot = 'morning';
    } else if (walkHour < 17) {
      walkTimeSlot = 'afternoon';
    } else {
      walkTimeSlot = 'evening';
    }

    return walkerTimeSlots.contains(walkTimeSlot) ? 1.0 : 0.5;
  }

  /// Urgency score: walks scheduled sooner get a slight boost
  /// Uses exponential decay: walks within 24 hours get higher scores
  static double _calculateUrgencyScore(DateTime walkTime) {
    final now = DateTime.now();
    final hoursUntilWalk = walkTime.difference(now).inHours;

    if (hoursUntilWalk < 0) return 0.0; // Past walks
    if (hoursUntilWalk <= 24) {
      // Within 24 hours: score from 1.0 to 0.8
      return 1.0 - (hoursUntilWalk / 24.0) * 0.2;
    } else if (hoursUntilWalk <= 168) {
      // Within a week: score from 0.8 to 0.6
      return 0.8 - ((hoursUntilWalk - 24) / 144.0) * 0.2;
    } else {
      // More than a week: base score of 0.6
      return 0.6;
    }
  }

  /// Sorts walk requests by relevance score (highest first)
  /// Time Complexity: O(n log n) for sorting
  static List<WalkRequestModel> sortByRelevance({
    required List<WalkRequestModel> requests,
    required Map<String, DogModel> dogs,
    required UserModel walker,
  }) {
    final scoredRequests = <({WalkRequestModel request, double score})>[];

    for (final request in requests) {
      final dog = dogs[request.dogId];
      if (dog == null) continue;

      final score = calculateRelevanceScore(
        walkRequest: request,
        dog: dog,
        walker: walker,
      );

      scoredRequests.add((request: request, score: score));
    }

    // Sort by score descending
    scoredRequests.sort((a, b) => b.score.compareTo(a.score));

    return scoredRequests.map((item) => item.request).toList();
  }
}
