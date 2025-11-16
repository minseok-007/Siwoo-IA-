import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/walk_application_model.dart';

/// Service for managing walk applications.
/// - Handles CRUD operations for walker applications
/// - Manages application status updates
class WalkApplicationService {
  final CollectionReference applicationsCollection =
      FirebaseFirestore.instance.collection('walk_applications');

  /// Add a new walk application
  Future<void> addApplication(WalkApplicationModel application) async {
    await applicationsCollection.doc(application.id).set(application.toFirestore());
  }

  /// Update an existing application
  Future<void> updateApplication(WalkApplicationModel application) async {
    await applicationsCollection
        .doc(application.id)
        .update(application.toFirestore());
  }

  /// Delete an application
  Future<void> deleteApplication(String applicationId) async {
    await applicationsCollection.doc(applicationId).delete();
  }

  /// Get all applications for a specific walk request
  Future<List<WalkApplicationModel>> getApplicationsByWalkRequest(
      String walkRequestId) async {
    final query = await applicationsCollection
        .where('walkRequestId', isEqualTo: walkRequestId)
        .get();
    return query.docs
        .map((doc) => WalkApplicationModel.fromFirestore(doc))
        .toList();
  }

  /// Get all pending applications for a walk request
  Future<List<WalkApplicationModel>> getPendingApplicationsByWalkRequest(
      String walkRequestId) async {
    final query = await applicationsCollection
        .where('walkRequestId', isEqualTo: walkRequestId)
        .where('status', isEqualTo: 'pending')
        .get();
    return query.docs
        .map((doc) => WalkApplicationModel.fromFirestore(doc))
        .toList();
  }

  /// Get all applications by a specific walker
  Future<List<WalkApplicationModel>> getApplicationsByWalker(
      String walkerId) async {
    final query = await applicationsCollection
        .where('walkerId', isEqualTo: walkerId)
        .get();
    return query.docs
        .map((doc) => WalkApplicationModel.fromFirestore(doc))
        .toList();
  }

  /// Get all applications for requests owned by a specific owner
  Future<List<WalkApplicationModel>> getApplicationsByOwner(
      String ownerId) async {
    final query = await applicationsCollection
        .where('ownerId', isEqualTo: ownerId)
        .get();
    return query.docs
        .map((doc) => WalkApplicationModel.fromFirestore(doc))
        .toList();
  }

  /// Check if a walker has already applied for a walk request
  Future<bool> hasWalkerApplied(String walkRequestId, String walkerId) async {
    final query = await applicationsCollection
        .where('walkRequestId', isEqualTo: walkRequestId)
        .where('walkerId', isEqualTo: walkerId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Get application by ID
  Future<WalkApplicationModel?> getApplicationById(String applicationId) async {
    final doc = await applicationsCollection.doc(applicationId).get();
    if (doc.exists) {
      return WalkApplicationModel.fromFirestore(doc);
    }
    return null;
  }

  /// Withdraw an application (walker cancels their application)
  Future<void> withdrawApplication(String applicationId) async {
    final application = await getApplicationById(applicationId);
    if (application != null) {
      final updated = application.copyWith(
        status: ApplicationStatus.withdrawn,
        updatedAt: DateTime.now(),
      );
      await updateApplication(updated);
    }
  }

  /// Accept an application (owner selects a walker)
  Future<void> acceptApplication(String applicationId) async {
    final application = await getApplicationById(applicationId);
    if (application != null) {
      final updated = application.copyWith(
        status: ApplicationStatus.accepted,
        updatedAt: DateTime.now(),
      );
      await updateApplication(updated);
    }
  }

  /// Reject an application (owner declines a walker)
  Future<void> rejectApplication(String applicationId) async {
    final application = await getApplicationById(applicationId);
    if (application != null) {
      final updated = application.copyWith(
        status: ApplicationStatus.rejected,
        updatedAt: DateTime.now(),
      );
      await updateApplication(updated);
    }
  }
}

