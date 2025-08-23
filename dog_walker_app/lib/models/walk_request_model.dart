import 'package:cloud_firestore/cloud_firestore.dart';

enum WalkRequestStatus { pending, accepted, completed, cancelled }

class WalkRequestModel {
  final String id;
  final String ownerId;
  final String? walkerId;
  final String dogId;
  final DateTime time;
  final String location;
  final String? notes;
  final WalkRequestStatus status;
  final int duration; // in minutes
  final double? budget; // in dollars
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

  factory WalkRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkRequestModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      walkerId: data['walkerId'],
      dogId: data['dogId'] ?? '',
      time: data['time'] != null ? (data['time'] as Timestamp).toDate() : DateTime.now(),
      location: data['location'] ?? '',
      notes: data['notes'],
      status: WalkRequestStatus.values.firstWhere(
        (e) => e.toString() == 'WalkRequestStatus.' + (data['status'] ?? 'pending'),
        orElse: () => WalkRequestStatus.pending,
      ),
      duration: data['duration'] ?? 30,
      budget: data['budget']?.toDouble(),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

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