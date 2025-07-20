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

  WalkRequestModel({
    required this.id,
    required this.ownerId,
    this.walkerId,
    required this.dogId,
    required this.time,
    required this.location,
    this.notes,
    this.status = WalkRequestStatus.pending,
  });

  factory WalkRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkRequestModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      walkerId: data['walkerId'],
      dogId: data['dogId'] ?? '',
      time: (data['time'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      notes: data['notes'],
      status: WalkRequestStatus.values.firstWhere(
        (e) => e.toString() == 'WalkRequestStatus.' + (data['status'] ?? 'pending'),
        orElse: () => WalkRequestStatus.pending,
      ),
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
    );
  }
} 