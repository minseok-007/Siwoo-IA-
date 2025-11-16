/* Summary: Manage walk applications as a separate model to allow multiple walkers
   to apply for the same walk request, and owners to choose from applicants.
   WHAT/HOW: Store consistently with Timestamps and status tracking. */
import 'package:cloud_firestore/cloud_firestore.dart';

/// Application status enum
enum ApplicationStatus { pending, accepted, rejected, withdrawn }

/// Walk application domain model.
/// - Tracks walker applications for walk requests
/// - Allows owners to review and select from multiple applicants
class WalkApplicationModel {
  final String id;
  final String walkRequestId;
  final String walkerId;
  final String ownerId;
  final ApplicationStatus status;
  final String? message; // Optional message from walker
  final DateTime createdAt;
  final DateTime updatedAt;

  WalkApplicationModel({
    required this.id,
    required this.walkRequestId,
    required this.walkerId,
    required this.ownerId,
    this.status = ApplicationStatus.pending,
    this.message,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Firestore → WalkApplicationModel conversion.
  factory WalkApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkApplicationModel(
      id: doc.id,
      walkRequestId: data['walkRequestId'] ?? '',
      walkerId: data['walkerId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.toString() == 'ApplicationStatus.${data['status']}',
        orElse: () => ApplicationStatus.pending,
      ),
      message: data['message'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// WalkApplicationModel → Firestore-ready Map.
  Map<String, dynamic> toFirestore() {
    return {
      'walkRequestId': walkRequestId,
      'walkerId': walkerId,
      'ownerId': ownerId,
      'status': status.toString().split('.').last,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// `copyWith` helper for the immutable model.
  WalkApplicationModel copyWith({
    String? id,
    String? walkRequestId,
    String? walkerId,
    String? ownerId,
    ApplicationStatus? status,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalkApplicationModel(
      id: id ?? this.id,
      walkRequestId: walkRequestId ?? this.walkRequestId,
      walkerId: walkerId ?? this.walkerId,
      ownerId: ownerId ?? this.ownerId,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

