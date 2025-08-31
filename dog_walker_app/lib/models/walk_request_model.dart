import 'package:cloud_firestore/cloud_firestore.dart';

/// 산책 요청 상태. 상태 머신을 단순화하기 위해 명확한 단계만 유지합니다.
enum WalkRequestStatus { pending, accepted, completed, cancelled }

/// 산책 요청 도메인 모델.
/// - 생성/업데이트 시간은 DateTime으로 관리하고, 저장 시 Timestamp로 변환합니다.
class WalkRequestModel {
  final String id;
  final String ownerId;
  final String? walkerId;
  final String dogId;
  final DateTime time;
  final String location;
  final String? notes;
  final WalkRequestStatus status;
  final int duration; // 분 단위. UI에서만 시간/분 변환
  final double? budget; // 예산(통화 단위는 UI에서 표현)
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

  /// Firestore → WalkRequestModel 변환.
  /// - 널/타입 이슈에 방어적으로 대응합니다.
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

  /// WalkRequestModel → Firestore 저장 Map.
  /// - enum은 슬러그 저장, DateTime은 Timestamp 저장으로 일관성을 유지합니다.
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

  /// 불변 모델을 위한 copyWith. 선택 필드만 변경 가능합니다.
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
