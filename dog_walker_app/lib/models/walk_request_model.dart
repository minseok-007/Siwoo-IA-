/* Summary: Manage walk requests as a dedicated model to avoid scheduling conflicts
   and keep state transitions clear. WHAT/HOW: Store consistently with slugs and
   Timestamps. */
import 'package:cloud_firestore/cloud_firestore.dart';

// Keep the state machine compact to reduce room for bugs.
/// Walk request status that keeps only the essential steps.
enum WalkRequestStatus { pending, accepted, completed, cancelled }

// Model around the domain to lower coupling with payments, notifications, and calendars.
/// Walk request domain model.
/// - Track created/updated times as DateTime values and convert to Timestamps when saving.
class WalkRequestModel {
  final String id;
  final String ownerId;
  final String? walkerId;
  final String dogId;
  final DateTime time;
  final String location;
  final String? notes;
  final WalkRequestStatus status;
  final int duration; // Minutes; convert to hours/minutes only in the UI
  final double? budget; // Budget amount; UI decides which currency to display
  final DateTime createdAt;
  final DateTime updatedAt;

  WalkRequestModel({
    required this.id,
    required this.ownerId,
    this.walkerId,
    required this.dogId,
    required this.time,
    required this.location,
    this.notes,
    this.status = WalkRequestStatus.pending,
    this.duration = 30,
    this.budget,
    required this.createdAt,
    required this.updatedAt,
  });

  // Use defensive defaults so external data restores safely into the domain model.
  /// Firestore → WalkRequestModel conversion.
  /// - Guard against null/type issues with fallback values.
  factory WalkRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkRequestModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      walkerId: data['walkerId'],
      dogId: data['dogId'] ?? '',
      time: data['time'] != null ? (data['time'] as Timestamp).toDate() : DateTime.now(), // Avoid null-time crashes
      location: data['location'] ?? '',
      notes: data['notes'],
      status: WalkRequestStatus.values.firstWhere(
        (e) => e.toString() == 'WalkRequestStatus.' + (data['status'] ?? 'pending'), // Rehydrate enum from slug
        orElse: () => WalkRequestStatus.pending,
      ),
      duration: data['duration'] ?? 30,
      budget: data['budget']?.toDouble(),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(), // Default keeps rollbacks safe
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(), // Same safeguard here
    );
  }

  // Store with slugs and Timestamps so the schema stays query/index friendly.
  /// WalkRequestModel → Firestore-ready Map.
  /// - Persist enums as slugs and DateTimes as Timestamps for consistency.
  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'walkerId': walkerId,
      'dogId': dogId,
      'time': Timestamp.fromDate(time),
      'location': location,
      'notes': notes,
      'status': status.toString().split('.').last,
      'duration': duration,
      'budget': budget,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Create partial-update copies to track history while keeping the model immutable.
  /// `copyWith` helper for the immutable model; update only the fields you need.
  WalkRequestModel copyWith({
    String? id,
    String? ownerId,
    String? walkerId,
    String? dogId,
    DateTime? time,
    String? location,
    String? notes,
    WalkRequestStatus? status,
    int? duration,
    double? budget,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalkRequestModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      walkerId: walkerId ?? this.walkerId,
      dogId: dogId ?? this.dogId,
      time: time ?? this.time,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      duration: duration ?? this.duration,
      budget: budget ?? this.budget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 
