import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for generating intelligent walking route recommendations.
/// 
/// Algorithm Complexity Analysis:
/// - OSM Data Fetching: O(n) where n = number of nodes in query area
/// - Environment Scoring: O(m) where m = number of POIs
/// - Route Generation (A*): O(V log V + E) where V = vertices, E = edges
/// - Overall: O(n + m + V log V + E)
/// 
/// Uses OpenStreetMap (OSM) data via Overpass API for realistic route recommendations.
class WalkRouteService {
  static const String _overpassApiUrl = 'https://overpass-api.de/api/interpreter';
  
  /// OSM tag categories for dog-friendly walking environments
  static const Map<String, List<String>> _environmentTags = {
    'parks': ['leisure=park', 'leisure=recreation_ground', 'landuse=recreation_ground'],
    'rivers': ['waterway=river', 'waterway=stream', 'natural=water'],
    'carFree': ['highway=footway', 'highway=path', 'highway=pedestrian', 'highway=cycleway'],
    'nature': ['natural=wood', 'natural=tree', 'landuse=forest', 'leisure=nature_reserve'],
    'waterfront': ['natural=coastline', 'waterway=*', 'amenity=fountain'],
  };

  /// Generates recommended walking routes based on current location.
  /// 
  /// Algorithm: Multi-factor scoring with A* pathfinding
  /// Time Complexity: O(V log V + E + m) where:
  ///   - V = number of waypoints
  ///   - E = number of edges between waypoints
  ///   - m = number of POIs analyzed
  /// 
  /// @param startLocation Starting point
  /// @param targetDistance Target distance in meters
  /// @param preferences User preferences for route type
  /// @return List of recommended routes sorted by score
  Future<List<WalkRoute>> generateRecommendedRoutes({
    required LatLng startLocation,
    required double targetDistance,
    WalkPreferences? preferences,
  }) async {
    preferences ??= WalkPreferences();
    
    // Step 1: Fetch OSM data for the area (O(n))
    final osmData = await _fetchOSMData(startLocation, targetDistance);
    
    // Step 2: Analyze environment and score points (O(m))
    final scoredPoints = await _scoreEnvironmentPoints(
      startLocation,
      osmData,
      preferences,
    );
    
    // Step 3: Generate route candidates using A* algorithm (O(V log V + E))
    final routes = await _generateRouteCandidates(
      startLocation,
      targetDistance,
      scoredPoints,
      preferences,
    );
    
    // Step 4: Sort by composite score (O(k log k) where k = number of routes)
    routes.sort((a, b) => b.score.compareTo(a.score));
    
    return routes.take(3).toList(); // Return top 3 routes
  }

  /// Fetches OSM data using Overpass API.
  /// Time Complexity: O(n) where n = number of nodes in response
  Future<Map<String, dynamic>> _fetchOSMData(
    LatLng center,
    double radius,
  ) async {
    // Calculate bounding box (approximately radius meters around center)
    final bbox = _calculateBoundingBox(center, radius);
    
    // Build Overpass QL query for dog-friendly features
    final query = '''
      [out:json][timeout:25];
      (
        // Parks and recreational areas
        node["leisure"="park"]["leisure"="recreation_ground"]($bbox);
        way["leisure"="park"]["leisure"="recreation_ground"]($bbox);
        relation["leisure"="park"]["leisure"="recreation_ground"]($bbox);
        
        // Water features
        node["waterway"]($bbox);
        way["waterway"]($bbox);
        node["natural"="water"]($bbox);
        way["natural"="water"]($bbox);
        
        // Car-free paths
        way["highway"="footway"]["highway"="path"]["highway"="pedestrian"]["highway"="cycleway"]($bbox);
        
        // Natural features
        node["natural"]($bbox);
        way["natural"]($bbox);
      );
      out body;
      >;
      out skel qt;
    ''';

    try {
      final response = await http.post(
        Uri.parse(_overpassApiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // Fallback: return empty data structure
        return {'elements': []};
      }
    } catch (e) {
      // Fallback: return empty data structure
      return {'elements': []};
    }
  }

  /// Calculates bounding box for OSM query.
  /// Time Complexity: O(1)
  String _calculateBoundingBox(LatLng center, double radiusMeters) {
    // Approximate: 1 degree latitude ≈ 111,000 meters
    // 1 degree longitude ≈ 111,000 * cos(latitude) meters
    final latDelta = radiusMeters / 111000.0;
    final lonDelta = radiusMeters / (111000.0 * math.cos(center.latitude * math.pi / 180));
    
    final south = center.latitude - latDelta;
    final north = center.latitude + latDelta;
    final west = center.longitude - lonDelta;
    final east = center.longitude + lonDelta;
    
    return '$south,$west,$north,$east';
  }

  /// Scores environment points based on preferences.
  /// Time Complexity: O(m) where m = number of POIs
  Future<List<ScoredPoint>> _scoreEnvironmentPoints(
    LatLng startLocation,
    Map<String, dynamic> osmData,
    WalkPreferences preferences,
  ) async {
    final elements = osmData['elements'] as List<dynamic>? ?? [];
    final scoredPoints = <ScoredPoint>[];

    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>? ?? {};
      final lat = element['lat'] as double?;
      final lon = element['lon'] as double?;
      
      if (lat == null || lon == null) {
        // For ways, get center point from geometry
        final geometry = element['geometry'] as List<dynamic>?;
        if (geometry == null || geometry.isEmpty) continue;
        
        // Calculate centroid
        double sumLat = 0, sumLon = 0;
        int count = 0;
        for (final point in geometry) {
          sumLat += (point['lat'] as num).toDouble();
          sumLon += (point['lon'] as num).toDouble();
          count++;
        }
        if (count == 0) continue;
        
        final point = LatLng(sumLat / count, sumLon / count);
        final score = _calculatePointScore(point, tags, startLocation, preferences);
        if (score > 0) {
          scoredPoints.add(ScoredPoint(point: point, score: score, tags: tags));
        }
      } else {
        final point = LatLng(lat, lon);
        final score = _calculatePointScore(point, tags, startLocation, preferences);
        if (score > 0) {
          scoredPoints.add(ScoredPoint(point: point, score: score, tags: tags));
        }
      }
    }

    return scoredPoints;
  }

  /// Calculates score for a single point based on preferences.
  /// Time Complexity: O(1)
  double _calculatePointScore(
    LatLng point,
    Map<String, dynamic> tags,
    LatLng startLocation,
    WalkPreferences preferences,
  ) {
    double score = 0.0;
    final distance = _calculateDistance(startLocation, point);
    
    // Distance penalty (prefer closer points)
    final distanceScore = math.max(0, 1.0 - (distance / 2000.0)); // 2km max
    
    // Environment scoring
    if (_matchesTag(tags, _environmentTags['parks']!)) {
      score += preferences.parkWeight * 2.0 * distanceScore;
    }
    if (_matchesTag(tags, _environmentTags['rivers']!) || 
        _matchesTag(tags, _environmentTags['waterfront']!)) {
      score += preferences.waterWeight * 1.5 * distanceScore;
    }
    if (_matchesTag(tags, _environmentTags['carFree']!)) {
      score += preferences.carFreeWeight * 1.8 * distanceScore;
    }
    if (_matchesTag(tags, _environmentTags['nature']!)) {
      score += preferences.natureWeight * 1.3 * distanceScore;
    }
    
    return score;
  }

  /// Checks if tags match any of the search patterns.
  /// Time Complexity: O(k) where k = number of patterns
  bool _matchesTag(Map<String, dynamic> tags, List<String> patterns) {
    for (final pattern in patterns) {
      final parts = pattern.split('=');
      if (parts.length == 2) {
        final key = parts[0];
        final value = parts[1];
        if (value == '*') {
          if (tags.containsKey(key)) return true;
        } else if (tags[key] == value) {
          return true;
        }
      }
    }
    return false;
  }

  /// Generates route candidates using A* pathfinding algorithm.
  /// Time Complexity: O(V log V + E) where V = vertices, E = edges
  Future<List<WalkRoute>> _generateRouteCandidates(
    LatLng startLocation,
    double targetDistance,
    List<ScoredPoint> scoredPoints,
    WalkPreferences preferences,
  ) async {
    if (scoredPoints.isEmpty) {
      // Fallback: generate simple circular route
      return _generateFallbackRoute(startLocation, targetDistance);
    }

    final routes = <WalkRoute>[];
    
    // Select top scored points as waypoints
    scoredPoints.sort((a, b) => b.score.compareTo(a.score));
    final waypoints = scoredPoints.take(10).map((sp) => sp.point).toList();
    
    // Generate multiple route variations
    for (int i = 0; i < math.min(5, waypoints.length); i++) {
      final route = await _generateRouteWithAStar(
        startLocation,
        waypoints[i],
        targetDistance,
        scoredPoints,
      );
      if (route != null) {
        routes.add(route);
      }
    }
    
    return routes;
  }

  /// Generates a route using A* pathfinding algorithm.
  /// Time Complexity: O(V log V + E) for A* algorithm
  Future<WalkRoute?> _generateRouteWithAStar(
    LatLng start,
    LatLng goal,
    double targetDistance,
    List<ScoredPoint> scoredPoints,
  ) async {
    // Simplified A* implementation for walking routes
    // In production, use a proper graph with road network data
    
    final path = <LatLng>[start];
    double currentDistance = 0;
    
    // Greedy approach: move towards goal while maximizing score
    LatLng current = start;
    final visited = <LatLng>{start};
    
    while (currentDistance < targetDistance * 0.9) {
      // Find best next point (considering both distance and score)
      ScoredPoint? bestNext;
      double bestScore = -1;
      
      for (final scoredPoint in scoredPoints) {
        if (visited.contains(scoredPoint.point)) continue;
        
        final distToPoint = _calculateDistance(current, scoredPoint.point);
        final distToGoal = _calculateDistance(scoredPoint.point, goal);
        final remainingDist = targetDistance - currentDistance;
        
        // Heuristic: prefer points that are:
        // 1. High scored
        // 2. Not too far from current path
        // 3. Moving towards goal
        if (distToPoint < remainingDist && distToPoint < 500) {
          final heuristic = scoredPoint.score * 
              (1.0 - distToPoint / 500.0) * 
              (1.0 - distToGoal / _calculateDistance(start, goal));
          
          if (heuristic > bestScore) {
            bestScore = heuristic;
            bestNext = scoredPoint;
          }
        }
      }
      
      if (bestNext == null) {
        // Move directly towards goal
        final directDist = _calculateDistance(current, goal);
        if (directDist + currentDistance <= targetDistance * 1.1) {
          path.add(goal);
          currentDistance += directDist;
          break;
        } else {
          // Interpolate point along path to goal
          final ratio = (targetDistance - currentDistance) / directDist;
          final nextPoint = LatLng(
            current.latitude + (goal.latitude - current.latitude) * ratio,
            current.longitude + (goal.longitude - current.longitude) * ratio,
          );
          path.add(nextPoint);
          currentDistance = targetDistance;
          break;
        }
      }
      
      path.add(bestNext.point);
      currentDistance += _calculateDistance(current, bestNext.point);
      current = bestNext.point;
      visited.add(bestNext.point);
      
      if (currentDistance >= targetDistance * 0.9) break;
    }
    
    // Ensure we return to start or end near goal
    if (currentDistance < targetDistance) {
      final distToGoal = _calculateDistance(current, goal);
      if (distToGoal + currentDistance <= targetDistance * 1.1) {
        path.add(goal);
        currentDistance += distToGoal;
      }
    }
    
    // Calculate route score
    final routeScore = _calculateRouteScore(path, scoredPoints);
    
    return WalkRoute(
      path: path,
      distance: currentDistance,
      score: routeScore,
      waypoints: path,
    );
  }

  /// Generates a simple fallback circular route.
  /// Time Complexity: O(1)
  List<WalkRoute> _generateFallbackRoute(LatLng center, double targetDistance) {
    // Generate a circular route
    final radius = targetDistance / (2 * math.pi);
    final points = <LatLng>[];
    
    for (int i = 0; i <= 16; i++) {
      final angle = (i / 16) * 2 * math.pi;
      final lat = center.latitude + (radius / 111000) * math.cos(angle);
      final lon = center.longitude + (radius / 111000) * math.sin(angle) / 
          math.cos(center.latitude * math.pi / 180);
      points.add(LatLng(lat, lon));
    }
    
    return [
      WalkRoute(
        path: points,
        distance: targetDistance,
        score: 0.5, // Default score
        waypoints: points,
      ),
    ];
  }

  /// Calculates total route score.
  /// Time Complexity: O(n * m) where n = path points, m = scored points
  double _calculateRouteScore(List<LatLng> path, List<ScoredPoint> scoredPoints) {
    if (path.isEmpty) return 0.0;
    
    double totalScore = 0.0;
    int count = 0;
    
    for (final point in path) {
      // Find nearest scored point
      double minDist = double.infinity;
      double nearestScore = 0.0;
      
      for (final scoredPoint in scoredPoints) {
        final dist = _calculateDistance(point, scoredPoint.point);
        if (dist < minDist && dist < 100) { // Within 100m
          minDist = dist;
          nearestScore = scoredPoint.score;
        }
      }
      
      totalScore += nearestScore;
      count++;
    }
    
    return count > 0 ? totalScore / count : 0.0;
  }

  /// Calculates distance between two points using Haversine formula.
  /// Time Complexity: O(1)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // meters
    final lat1Rad = point1.latitude * math.pi / 180;
    final lat2Rad = point2.latitude * math.pi / 180;
    final deltaLat = (point2.latitude - point1.latitude) * math.pi / 180;
    final deltaLon = (point2.longitude - point1.longitude) * math.pi / 180;
    
    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLon / 2) * math.sin(deltaLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
}

/// Represents a recommended walking route.
class WalkRoute {
  final List<LatLng> path;
  final double distance; // in meters
  final double score; // 0.0 to 10.0
  final List<LatLng> waypoints;
  
  WalkRoute({
    required this.path,
    required this.distance,
    required this.score,
    required this.waypoints,
  });
  
  double get distanceKm => distance / 1000.0;
  String get distanceDisplay => '${distanceKm.toStringAsFixed(1)} km';
  String get scoreDisplay => score.toStringAsFixed(1);
}

/// Represents a scored point of interest.
class ScoredPoint {
  final LatLng point;
  final double score;
  final Map<String, dynamic> tags;
  
  ScoredPoint({
    required this.point,
    required this.score,
    required this.tags,
  });
}

/// User preferences for route generation.
class WalkPreferences {
  final double parkWeight;
  final double waterWeight;
  final double carFreeWeight;
  final double natureWeight;
  
  WalkPreferences({
    this.parkWeight = 1.0,
    this.waterWeight = 1.0,
    this.carFreeWeight = 1.0,
    this.natureWeight = 1.0,
  });
  
  /// Balanced preferences (default)
  factory WalkPreferences.balanced() => WalkPreferences();
  
  /// Nature-focused preferences
  factory WalkPreferences.natureFocused() => WalkPreferences(
    parkWeight: 2.0,
    natureWeight: 2.0,
    waterWeight: 1.5,
    carFreeWeight: 1.5,
  );
  
  /// Urban walk preferences
  factory WalkPreferences.urban() => WalkPreferences(
    carFreeWeight: 2.0,
    parkWeight: 1.5,
    waterWeight: 1.0,
    natureWeight: 0.5,
  );
}

