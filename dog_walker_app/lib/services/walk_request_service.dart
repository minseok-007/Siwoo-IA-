import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_request_model.dart';

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
    final query = await walkRequestsCollection.where('walkerId', isEqualTo: walkerId).get();
    return query.docs.map((doc) => WalkRequestModel.fromFirestore(doc)).toList();
  }

  Future<WalkRequestModel?> getRequestById(String requestId) async {
    final doc = await walkRequestsCollection.doc(requestId).get();
    if (doc.exists) {
      return WalkRequestModel.fromFirestore(doc);
    }
    return null;
  }
} 