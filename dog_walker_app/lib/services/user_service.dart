import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// 사용자(users) 컬렉션 접근용 서비스.
/// - GeoPoint를 활용한 근사 거리 계산 등 단순 비즈니스 로직도 함께 포함합니다.
class UserService {
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('users');

  Future<UserModel?> getUserById(String userId) async {
    try {
      final DocumentSnapshot doc = await usersCollection.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    try {
      await usersCollection.doc(user.id).set(user.toFirestore());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await usersCollection.doc(user.id).update(user.toFirestore());
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await usersCollection.doc(userId).delete();
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  /// 매칭을 위한 워커 전체 조회 (간단 필터 포함)
  Future<List<UserModel>> getAllWalkers() async {
    try {
      final QuerySnapshot querySnapshot = await usersCollection
          .where('userType', isEqualTo: 'dogWalker')
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user != null)
          .cast<UserModel>()
          .toList();
    } catch (e) {
      print('Error fetching walkers: $e');
      return [];
    }
  }

  /// 특정 반경 내 워커 조회 (개발용 근사 구현).
  Future<List<UserModel>> getWalkersInArea(GeoPoint center, double radiusKm) async {
    try {
      // Note: This is a simplified approach. For production, consider using
      // Firestore's GeoFirestore or similar geospatial indexing solutions
      final QuerySnapshot querySnapshot = await usersCollection
          .where('userType', isEqualTo: 'dogWalker')
          .get();
      
      final walkers = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user != null)
          .cast<UserModel>()
          .toList();
      
      // Filter by distance (this could be optimized with proper geospatial queries)
      return walkers.where((walker) {
        if (walker.location == null) return false;
        
        final distance = _calculateDistance(center, walker.location!);
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      print('Error fetching walkers in area: $e');
      return [];
    }
  }

  /// 거리 계산 (Haversine 공식). 서버 인덱스 없이 클라이언트에서 근사 필터링 시 사용합니다.
  double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    const double earthRadius = 6371.0; // Earth's radius in kilometers
    
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    final double deltaLon = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
} 
