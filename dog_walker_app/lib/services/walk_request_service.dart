import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_request_model.dart';

/// 산책 요청(walk_requests) 컬렉션을 다루는 서비스.
/// - 인덱스 요구를 피하기 위해 일부 정렬은 메모리에서 처리합니다(개발 단계 최적화).
class WalkRequestService {
  final CollectionReference walkRequestsCollection = FirebaseFirestore.instance.collection('walk_requests');

  Future<void> addWalkRequest(WalkRequestModel request) async {
    await walkRequestsCollection.doc(request.id).set(request.toFirestore());
  }

  Future<void> updateWalkRequest(WalkRequestModel request) async {
    await walkRequestsCollection.doc(request.id).update(request.toFirestore());
  }

  Future<void> deleteWalkRequest(String requestId) async {
    await walkRequestsCollection.doc(requestId).delete();
  }

  Future<List<WalkRequestModel>> getRequestsByOwner(String ownerId) async {
    final query = await walkRequestsCollection.where('ownerId', isEqualTo: ownerId).get();
    return query.docs.map((doc) => WalkRequestModel.fromFirestore(doc)).toList();
  }

  Future<List<WalkRequestModel>> getAvailableRequests() async {
    final query = await walkRequestsCollection.where('status', isEqualTo: 'pending').get();
    return query.docs.map((doc) => WalkRequestModel.fromFirestore(doc)).toList();
  }

  Future<List<WalkRequestModel>> getRequestsByWalker(String walkerId) async {
    try {
      // Temporarily remove orderBy to avoid index requirement
      final querySnapshot = await walkRequestsCollection
          .where('walkerId', isEqualTo: walkerId)
          .get();
      
      // Sort in memory instead
      final requests = querySnapshot.docs
          .map((doc) => WalkRequestModel.fromFirestore(doc))
          .toList();
      
      // Sort by time descending
      requests.sort((a, b) => b.time.compareTo(a.time));
      
      return requests;
    } catch (e) {
      throw Exception('Failed to fetch walker requests: $e');
    }
  }

  Future<WalkRequestModel?> getRequestById(String requestId) async {
    final doc = await walkRequestsCollection.doc(requestId).get();
    if (doc.exists) {
      return WalkRequestModel.fromFirestore(doc);
    }
    return null;
  }
} 
