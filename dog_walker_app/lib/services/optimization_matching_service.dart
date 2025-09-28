import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/dog_traits.dart';
import '../models/walk_request_model.dart';

/// Optimization-based matching service
class OptimizationMatchingService {
  static const double _earthRadius = 6371.0;

  /// Hungarian Algorithm implementation
  static List<OptimalMatch> findOptimalMatches(
    List<UserModel> walkers,
    List<WalkRequestModel> walkRequests,
    Map<String, UserModel> owners,
    Map<String, DogModel> dogs, {
    OptimizationCriteria criteria = OptimizationCriteria.distanceAndTime,
  }) {
    if (walkers.isEmpty || walkRequests.isEmpty) return [];

    final int n = max(walkers.length, walkRequests.length);
    final List<List<double>> costMatrix = List.generate(
      n,
      (i) => List.generate(n, (j) => double.infinity),
    );

    for (int i = 0; i < walkers.length; i++) {
      for (int j = 0; j < walkRequests.length; j++) {
        final walkRequest = walkRequests[j];
        final owner = owners[walkRequest.ownerId];
        final dog = dogs[walkRequest.dogId];

        if (owner != null && dog != null) {
          final cost = _calculateOptimizationCost(
            walkers[i],
            walkRequest,
            owner,
            dog,
            walkers,
            walkRequests,
            criteria,
          );
          costMatrix[i][j] = cost;
        }
      }
    }

    final assignments = _hungarianAlgorithm(costMatrix);
    final List<OptimalMatch> results = [];

    for (int i = 0; i < assignments.length; i++) {
      final walkerIndex = i;
      final requestIndex = assignments[i];

      if (requestIndex < walkRequests.length &&
          walkerIndex < walkers.length &&
          costMatrix[walkerIndex][requestIndex] < double.infinity) {
        final walkRequest = walkRequests[requestIndex];
        final owner = owners[walkRequest.ownerId];
        final dog = dogs[walkRequest.dogId];

        if (owner != null && dog != null) {
          results.add(
            OptimalMatch(
              walker: walkers[walkerIndex],
              walkRequest: walkRequest,
              owner: owner,
              dog: dog,
              totalCost: costMatrix[walkerIndex][requestIndex],
              distance: _calculateDistance(
                walkers[walkerIndex].location!,
                owner.location!,
              ),
              timeConflict: _calculateTimeConflict(
                walkers[walkerIndex],
                walkRequest,
                walkRequests,
              ),
            ),
          );
        }
      }
    }

    return results;
  }

  static double _calculateOptimizationCost(
    UserModel walker,
    WalkRequestModel walkRequest,
    UserModel owner,
    DogModel dog,
    List<UserModel> allWalkers,
    List<WalkRequestModel> allRequests,
    OptimizationCriteria criteria,
  ) {
    if (walker.location == null || owner.location == null)
      return double.infinity;

    final distance = _calculateDistance(walker.location!, owner.location!);
    final distanceCost = distance * 0.4;
    final timeConflictCost =
        _calculateTimeConflict(walker, walkRequest, allRequests) * 0.3;
    final compatibilityCost =
        _calculateCompatibilityCost(walker, walkRequest, owner, dog) * 0.2;
    final efficiencyCost =
        _calculateEfficiencyCost(walker, walkRequest, allWalkers, allRequests) *
        0.1;

    double totalCost =
        distanceCost + timeConflictCost + compatibilityCost + efficiencyCost;

    switch (criteria) {
      case OptimizationCriteria.distanceOnly:
        totalCost = distanceCost * 2.0;
        break;
      case OptimizationCriteria.timeOnly:
        totalCost = timeConflictCost * 2.0;
        break;
      case OptimizationCriteria.distanceAndTime:
        break;
      case OptimizationCriteria.balanced:
        totalCost =
            (distanceCost +
                timeConflictCost +
                compatibilityCost +
                efficiencyCost) /
            4.0;
        break;
    }

    return totalCost;
  }

  static double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLon = (point2.longitude - point1.longitude) * pi / 180;

    final double a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  static double _calculateTimeConflict(
    UserModel walker,
    WalkRequestModel walkRequest,
    List<WalkRequestModel> allRequests,
  ) {
    final walkStart = walkRequest.startTime;
    final walkEnd = walkRequest.endTime;

    int conflicts = 0;
    for (final otherRequest in allRequests) {
      if (otherRequest.id == walkRequest.id) continue;
      if (otherRequest.walkerId != walker.id) continue;

      final otherStart = otherRequest.startTime;
      final otherEnd = otherRequest.endTime;

      if (walkStart.isBefore(otherEnd) && walkEnd.isAfter(otherStart)) {
        conflicts++;
      }
    }

    return conflicts * 10.0;
  }

  static double _calculateCompatibilityCost(
    UserModel walker,
    WalkRequestModel walkRequest,
    UserModel owner,
    DogModel dog,
  ) {
    double cost = 0.0;

    if (!walker.preferredDogSizes.contains(dog.size)) {
      cost += 5.0;
    }

    final dogDifficulty = _calculateDogDifficulty(dog);
    final walkerLevel = _getExperienceLevel(walker.experienceLevel);
    if (walkerLevel < dogDifficulty) {
      cost += (dogDifficulty - walkerLevel) * 3.0;
    }

    final walkHour = walkRequest.startTime.hour;
    String walkTimeSlot;
    if (walkHour < 12)
      walkTimeSlot = 'morning';
    else if (walkHour < 17)
      walkTimeSlot = 'afternoon';
    else
      walkTimeSlot = 'evening';

    if (!walker.preferredTimeSlots.contains(walkTimeSlot)) {
      cost += 3.0;
    }

    final walkDay = walkRequest.startTime.weekday % 7;
    if (!walker.availableDays.contains(walkDay)) {
      cost += 10.0;
    }

    return cost;
  }

  static double _calculateEfficiencyCost(
    UserModel walker,
    WalkRequestModel walkRequest,
    List<UserModel> allWalkers,
    List<WalkRequestModel> allRequests,
  ) {
    final currentWorkload = allRequests
        .where((r) => r.walkerId == walker.id)
        .length;
    final maxWorkload = 5;

    if (currentWorkload >= maxWorkload) {
      return 20.0;
    }

    final ratingCost = (5.0 - walker.rating) * 2.0;
    return ratingCost;
  }

  static int _calculateDogDifficulty(DogModel dog) {
    int difficulty = 1;

    if (dog.specialNeeds.contains(SpecialNeeds.training)) difficulty += 2;
    if (dog.specialNeeds.contains(SpecialNeeds.puppy)) difficulty += 1;
    if (dog.specialNeeds.contains(SpecialNeeds.elderly)) difficulty += 1;
    if (dog.temperament == DogTemperament.aggressive) difficulty += 2;
    if (dog.energyLevel == EnergyLevel.veryHigh) difficulty += 1;

    return difficulty;
  }

  static int _getExperienceLevel(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner:
        return 1;
      case ExperienceLevel.intermediate:
        return 2;
      case ExperienceLevel.expert:
        return 3;
    }
  }

  static List<int> _hungarianAlgorithm(List<List<double>> costMatrix) {
    final int n = costMatrix.length;
    final List<int> assignment = List.generate(n, (i) => -1);

    _subtractRowMinima(costMatrix);
    _subtractColMinima(costMatrix);

    while (true) {
      final List<int> rowCover = List.filled(n, 0);
      final List<int> colCover = List.filled(n, 0);

      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          if (costMatrix[i][j] == 0 && rowCover[i] == 0 && colCover[j] == 0) {
            assignment[i] = j;
            rowCover[i] = 1;
            colCover[j] = 1;
          }
        }
      }

      if (rowCover.every((cover) => cover == 1)) {
        break;
      }

      final List<int> uncoveredRows = [];
      final List<int> uncoveredCols = [];

      for (int i = 0; i < n; i++) {
        if (rowCover[i] == 0) uncoveredRows.add(i);
        if (colCover[i] == 0) uncoveredCols.add(i);
      }

      double minUncovered = double.infinity;
      for (int i in uncoveredRows) {
        for (int j in uncoveredCols) {
          if (costMatrix[i][j] < minUncovered) {
            minUncovered = costMatrix[i][j];
          }
        }
      }

      for (int i in uncoveredRows) {
        for (int j = 0; j < n; j++) {
          costMatrix[i][j] -= minUncovered;
        }
      }

      for (int j in uncoveredCols) {
        for (int i = 0; i < n; i++) {
          costMatrix[i][j] += minUncovered;
        }
      }
    }

    return assignment;
  }

  static void _subtractRowMinima(List<List<double>> matrix) {
    for (int i = 0; i < matrix.length; i++) {
      double minVal = matrix[i].reduce(min);
      for (int j = 0; j < matrix[i].length; j++) {
        matrix[i][j] -= minVal;
      }
    }
  }

  static void _subtractColMinima(List<List<double>> matrix) {
    for (int j = 0; j < matrix[0].length; j++) {
      double minVal = double.infinity;
      for (int i = 0; i < matrix.length; i++) {
        if (matrix[i][j] < minVal) {
          minVal = matrix[i][j];
        }
      }
      for (int i = 0; i < matrix.length; i++) {
        matrix[i][j] -= minVal;
      }
    }
  }
}

enum OptimizationCriteria { distanceOnly, timeOnly, distanceAndTime, balanced }

class OptimalMatch {
  final UserModel walker;
  final WalkRequestModel walkRequest;
  final UserModel owner;
  final DogModel dog;
  final double totalCost;
  final double distance;
  final double timeConflict;

  OptimalMatch({
    required this.walker,
    required this.walkRequest,
    required this.owner,
    required this.dog,
    required this.totalCost,
    required this.distance,
    required this.timeConflict,
  });

  @override
  String toString() {
    return 'OptimalMatch(walker: ${walker.fullName}, request: ${walkRequest.id}, cost: ${totalCost.toStringAsFixed(2)})';
  }
}

class MatchingQualityAnalysis {
  final int totalMatches;
  final double averageDistance;
  final double averageCost;
  final int timeConflicts;
  final double totalDistance;
  final double efficiency;

  MatchingQualityAnalysis({
    required this.totalMatches,
    required this.averageDistance,
    required this.averageCost,
    required this.timeConflicts,
    required this.totalDistance,
    required this.efficiency,
  });

  @override
  String toString() {
    return 'MatchingQuality(total: $totalMatches, avgDistance: ${averageDistance.toStringAsFixed(2)}km, efficiency: ${efficiency.toStringAsFixed(1)}%)';
  }
}
