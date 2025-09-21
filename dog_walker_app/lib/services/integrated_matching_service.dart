import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/walk_request_model.dart';
import 'optimization_matching_service.dart';
import 'location_service.dart';
import 'matching_service.dart';

class IntegratedMatchingService {
  static final IntegratedMatchingService _instance = IntegratedMatchingService._internal();
  factory IntegratedMatchingService() => _instance;
  IntegratedMatchingService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  
  Future<IntegratedMatchingResult> findOptimalMatches({
    required WalkRequestModel walkRequest,
    required UserModel owner,
    required DogModel dog,
    OptimizationCriteria criteria = OptimizationCriteria.distanceAndTime,
    int maxResults = 10,
    bool useLocationFiltering = true,
  }) async {
    try {
      List<UserModel> candidateWalkers = [];
      
      if (useLocationFiltering && owner.location != null) {
        candidateWalkers = await _locationService.findAvailableWalkers(
          location: owner.location!,
          maxDistance: 20.0,
          availableDays: [walkRequest.time.weekday % 7],
          timeSlots: _getTimeSlot(walkRequest.time),
          specificTime: walkRequest.time,
        );
      } else {
        final query = await _firestore
            .collection('users')
            .where('userType', isEqualTo: UserType.dogWalker.toString().split('.').last)
            .get();
        
        candidateWalkers = query.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList();
      }
      
      if (candidateWalkers.isEmpty) {
        return IntegratedMatchingResult(
          matches: [],
          quality: MatchingQualityAnalysis(
            totalMatches: 0,
            averageDistance: 0.0,
            averageCost: 0.0,
            timeConflicts: 0,
            totalDistance: 0.0,
            efficiency: 0.0,
          ),
          method: 'no_candidates',
        );
      }
      
      final optimalMatches = OptimizationMatchingService.findOptimalMatches(
        candidateWalkers,
        [walkRequest],
        {owner.id: owner},
        {dog.id: dog},
        criteria: criteria,
      );
      
      final traditionalMatches = MatchingService.findCompatibleMatches(
        candidateWalkers,
        walkRequest,
        owner,
        dog,
        maxResults: maxResults,
      );
      
      final integratedMatches = _integrateMatchingResults(
        optimalMatches,
        traditionalMatches,
        maxResults,
      );
      
      final quality = _analyzeMatchingQuality(integratedMatches);
      
      return IntegratedMatchingResult(
        matches: integratedMatches,
        quality: quality,
        method: 'integrated_optimization',
        traditionalMatches: traditionalMatches,
        optimalMatches: optimalMatches,
      );
      
    } catch (e) {
      print('Error in integrated matching: $e');
      return IntegratedMatchingResult(
        matches: [],
        quality: MatchingQualityAnalysis(
          totalMatches: 0,
          averageDistance: 0.0,
          averageCost: 0.0,
          timeConflicts: 0,
          totalDistance: 0.0,
          efficiency: 0.0,
        ),
        method: 'error',
        error: e.toString(),
      );
    }
  }
  
  Future<List<IntegratedMatch>> findRealTimeMatches({
    required String userId,
    required double maxDistance,
    required List<DogSize> preferredDogSizes,
    int maxResults = 5,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];
      
      final user = UserModel.fromFirestore(userDoc);
      if (user.location == null) return [];
      
      final nearbyWalkers = await _locationService.findNearbyUsers(
        center: user.location!,
        radiusKm: maxDistance,
        userType: UserType.dogWalker,
        limit: 20,
      );
      
      final List<IntegratedMatch> matches = [];
      
      for (final walker in nearbyWalkers) {
        final distance = LocationService.calculateDistance(user.location!, walker.location!);
        
        double compatibilityScore = 0.0;
        
        if (walker.preferredDogSizes.isNotEmpty && preferredDogSizes.isNotEmpty) {
          final commonSizes = walker.preferredDogSizes
              .where((size) => preferredDogSizes.contains(size))
              .length;
          compatibilityScore += (commonSizes / preferredDogSizes.length) * 0.4;
        }
        
        final distanceScore = (1.0 - (distance / maxDistance)).clamp(0.0, 1.0);
        compatibilityScore += distanceScore * 0.3;
        
        final ratingScore = walker.rating / 5.0;
        compatibilityScore += ratingScore * 0.2;
        
        final experienceScore = _getExperienceScore(walker.experienceLevel);
        compatibilityScore += experienceScore * 0.1;
        
        matches.add(IntegratedMatch(
          walker: walker,
          score: compatibilityScore,
          distance: distance,
          lastLocationUpdate: DateTime.now(),
          isRealTime: true,
        ));
      }
      
      matches.sort((a, b) => b.score.compareTo(a.score));
      return matches.take(maxResults).toList();
      
    } catch (e) {
      print('Error in real-time matching: $e');
      return [];
    }
  }
  
  List<IntegratedMatch> _integrateMatchingResults(
    List<OptimalMatch> optimalMatches,
    List<MatchResult> traditionalMatches,
    int maxResults,
  ) {
    final Map<String, IntegratedMatch> integratedMap = {};
    
    for (final optimal in optimalMatches) {
      final score = _calculateIntegratedScore(optimal, true);
      integratedMap[optimal.walker.id] = IntegratedMatch(
        walker: optimal.walker,
        score: score,
        distance: optimal.distance,
        lastLocationUpdate: DateTime.now(),
        isRealTime: false,
        optimalMatch: optimal,
      );
    }
    
    for (final traditional in traditionalMatches) {
      if (!integratedMap.containsKey(traditional.walker.id)) {
        final score = _calculateIntegratedScore(traditional, false);
        integratedMap[traditional.walker.id] = IntegratedMatch(
          walker: traditional.walker,
          score: score,
          distance: 0.0,
          lastLocationUpdate: DateTime.now(),
          isRealTime: false,
          traditionalMatch: traditional,
        );
      }
    }
    
    final results = integratedMap.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    
    return results.take(maxResults).toList();
  }
  
  double _calculateIntegratedScore(dynamic match, bool isOptimal) {
    if (isOptimal && match is OptimalMatch) {
      return (1.0 - (match.totalCost / 100.0)).clamp(0.0, 1.0);
    } else if (match is MatchResult) {
      return match.score;
    }
    return 0.0;
  }
  
  List<String> _getTimeSlot(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return ['morning'];
    if (hour < 17) return ['afternoon'];
    return ['evening'];
  }
  
  double _getExperienceScore(ExperienceLevel level) {
    switch (level) {
      case ExperienceLevel.beginner: return 0.3;
      case ExperienceLevel.intermediate: return 0.6;
      case ExperienceLevel.expert: return 1.0;
    }
  }
  
  MatchingQualityAnalysis _analyzeMatchingQuality(List<IntegratedMatch> matches) {
    if (matches.isEmpty) {
      return MatchingQualityAnalysis(
        totalMatches: 0,
        averageDistance: 0.0,
        averageCost: 0.0,
        timeConflicts: 0,
        totalDistance: 0.0,
        efficiency: 0.0,
      );
    }
    
    final totalDistance = matches.fold(0.0, (sum, match) => sum + match.distance);
    final averageDistance = totalDistance / matches.length;
    final averageCost = matches.fold(0.0, (sum, match) => sum + match.score) / matches.length;
    final timeConflicts = 0; // Simplified for now
    
    final maxPossibleCost = matches.length * 100.0;
    final efficiency = (1.0 - (averageCost / maxPossibleCost)) * 100.0;
    
    return MatchingQualityAnalysis(
      totalMatches: matches.length,
      averageDistance: averageDistance,
      averageCost: averageCost,
      timeConflicts: timeConflicts,
      totalDistance: totalDistance,
      efficiency: efficiency,
    );
  }
  
  LocationService get locationService => _locationService;
}

class IntegratedMatchingResult {
  final List<IntegratedMatch> matches;
  final MatchingQualityAnalysis quality;
  final String method;
  final String? error;
  final List<MatchResult>? traditionalMatches;
  final List<OptimalMatch>? optimalMatches;
  
  IntegratedMatchingResult({
    required this.matches,
    required this.quality,
    required this.method,
    this.error,
    this.traditionalMatches,
    this.optimalMatches,
  });
  
  @override
  String toString() {
    return 'IntegratedMatchingResult(matches: ${matches.length}, method: $method, efficiency: ${quality.efficiency.toStringAsFixed(1)}%)';
  }
}

class IntegratedMatch {
  final UserModel walker;
  final double score;
  final double distance;
  final DateTime lastLocationUpdate;
  final bool isRealTime;
  final OptimalMatch? optimalMatch;
  final MatchResult? traditionalMatch;
  
  IntegratedMatch({
    required this.walker,
    required this.score,
    required this.distance,
    required this.lastLocationUpdate,
    required this.isRealTime,
    this.optimalMatch,
    this.traditionalMatch,
  });
  
  @override
  String toString() {
    return 'IntegratedMatch(walker: ${walker.fullName}, score: ${score.toStringAsFixed(3)}, distance: ${distance.toStringAsFixed(2)}km)';
  }
}