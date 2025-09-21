import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_model.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStream;
  Position? _currentPosition;
  Timer? _locationUpdateTimer;
  
  static const Duration _updateInterval = Duration(minutes: 5);
  static const double _minDistanceChange = 100.0;
  
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status == PermissionStatus.granted;
  }
  
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
  
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await isLocationServiceEnabled()) {
        throw Exception('Location service is disabled');
      }
      
      final permission = await requestLocationPermission();
      if (!permission) {
        throw Exception('Location permission denied');
      }
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      _currentPosition = position;
      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }
  
  Future<void> startLocationTracking(String userId) async {
    try {
      if (!await isLocationServiceEnabled()) {
        throw Exception('Location service is disabled');
      }
      
      final permission = await requestLocationPermission();
      if (!permission) {
        throw Exception('Location permission denied');
      }
      
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _minDistanceChange,
        ),
      ).listen(
        (Position position) {
          _currentPosition = position;
          _updateUserLocation(userId, position);
        },
        onError: (error) {
          print('Location stream error: $error');
        },
      );
      
      _locationUpdateTimer = Timer.periodic(_updateInterval, (timer) {
        if (_currentPosition != null) {
          _updateUserLocation(userId, _currentPosition!);
        }
      });
      
    } catch (e) {
      print('Error starting location tracking: $e');
      rethrow;
    }
  }
  
  Future<void> stopLocationTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }
  
  Future<void> _updateUserLocation(String userId, Position position) async {
    try {
      final geoPoint = GeoPoint(position.latitude, position.longitude);
      
      await _firestore.collection('users').doc(userId).update({
        'location': geoPoint,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'locationAccuracy': position.accuracy,
      });
      
      print('Location updated for user $userId: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('Error updating user location: $e');
    }
  }
  
  Future<void> updateUserLocation(String userId, Position position) async {
    await _updateUserLocation(userId, position);
  }
  
  static double calculateDistance(GeoPoint point1, GeoPoint point2) {
    const double earthRadius = 6371.0;
    
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLon = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
  
  Future<List<UserModel>> findNearbyUsers({
    required GeoPoint center,
    required double radiusKm,
    required UserType userType,
    int limit = 50,
  }) async {
    try {
      final bounds = _calculateBounds(center, radiusKm);
      
      final query = await _firestore
          .collection('users')
          .where('userType', isEqualTo: userType.toString().split('.').last)
          .where('location', isGreaterThan: bounds['southwest'])
          .where('location', isLessThan: bounds['northeast'])
          .limit(limit)
          .get();
      
      final List<UserModel> nearbyUsers = [];
      
      for (final doc in query.docs) {
        final user = UserModel.fromFirestore(doc);
        if (user.location != null) {
          final distance = calculateDistance(center, user.location!);
          if (distance <= radiusKm) {
            nearbyUsers.add(user);
          }
        }
      }
      
      nearbyUsers.sort((a, b) {
        final distanceA = calculateDistance(center, a.location!);
        final distanceB = calculateDistance(center, b.location!);
        return distanceA.compareTo(distanceB);
      });
      
      return nearbyUsers;
    } catch (e) {
      print('Error finding nearby users: $e');
      return [];
    }
  }
  
  Map<String, GeoPoint> _calculateBounds(GeoPoint center, double radiusKm) {
    const double earthRadius = 6371.0;
    
    final double lat = center.latitude * pi / 180;
    final double lon = center.longitude * pi / 180;
    
    final double deltaLat = radiusKm / earthRadius * 180 / pi;
    final double deltaLon = radiusKm / (earthRadius * cos(lat)) * 180 / pi;
    
    return {
      'northeast': GeoPoint(
        center.latitude + deltaLat,
        center.longitude + deltaLon,
      ),
      'southwest': GeoPoint(
        center.latitude - deltaLat,
        center.longitude - deltaLon,
      ),
    };
  }
  
  Future<List<UserModel>> findAvailableWalkers({
    required GeoPoint location,
    required double maxDistance,
    required List<int> availableDays,
    required List<String> timeSlots,
    DateTime? specificTime,
  }) async {
    try {
      final nearbyWalkers = await findNearbyUsers(
        center: location,
        radiusKm: maxDistance,
        userType: UserType.dogWalker,
      );
      
      final List<UserModel> availableWalkers = [];
      
      for (final walker in nearbyWalkers) {
        final distance = calculateDistance(location, walker.location!);
        if (distance > maxDistance) continue;
        
        if (availableDays.isNotEmpty) {
          final walkDay = specificTime?.weekday % 7 ?? DateTime.now().weekday % 7;
          if (!walker.availableDays.contains(walkDay)) continue;
        }
        
        if (timeSlots.isNotEmpty && specificTime != null) {
          final walkHour = specificTime.hour;
          String walkTimeSlot;
          if (walkHour < 12) walkTimeSlot = 'morning';
          else if (walkHour < 17) walkTimeSlot = 'afternoon';
          else walkTimeSlot = 'evening';
          
          if (!walker.preferredTimeSlots.contains(walkTimeSlot)) continue;
        }
        
        availableWalkers.add(walker);
      }
      
      return availableWalkers;
    } catch (e) {
      print('Error finding available walkers: $e');
      return [];
    }
  }
  
  bool isLocationAccurate(Position position) {
    return position.accuracy <= 100.0;
  }
  
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _positionStream != null;
  
  void dispose() {
    stopLocationTracking();
  }
}

class LocationBasedMatch {
  final UserModel user;
  final double distance;
  final double accuracy;
  final DateTime lastUpdate;
  
  LocationBasedMatch({
    required this.user,
    required this.distance,
    required this.accuracy,
    required this.lastUpdate,
  });
  
  @override
  String toString() {
    return 'LocationBasedMatch(user: ${user.fullName}, distance: ${distance.toStringAsFixed(2)}km)';
  }
}