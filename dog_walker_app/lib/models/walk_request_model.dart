/* 요약: 일정 충돌을 방지하고 상태 전이를 명확히 하려는 의도로 산책 요청을
   독립 모델로 관리한다. WHAT/HOW: 슬러그와 Timestamp로 일관 저장한다. */
import 'package:cloud_firestore/cloud_firestore.dart';

// 상태 머신을 단순화해 버그 발생 여지를 줄이려는 목적이다.
/// 산책 요청 상태. 상태 머신을 단순화하기 위해 명확한 단계만 유지합니다.
enum WalkRequestStatus { pending, accepted, completed, cancelled }

// 결제·알림·캘린더와의 결합도를 낮추기 위해 도메인 중심으로 모델링한다.
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

  // 외부 저장 문서를 도메인으로 안전하게 복원하려고 기본값을 둔 방어적 처리를 한다.
  /// Firestore → WalkRequestModel 변환.
  /// - 널/타입 이슈에 방어적으로 대응합니다.
  factory WalkRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkRequestModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      walkerId: data['walkerId'],
      dogId: data['dogId'] ?? '',
      time: data['time'] != null ? (data['time'] as Timestamp).toDate() : DateTime.now(), // 빈값으로 인한 오류를 피하기 위함.
      location: data['location'] ?? '',
      notes: data['notes'],
      status: WalkRequestStatus.values.firstWhere(
        (e) => e.toString() == 'WalkRequestStatus.' + (data['status'] ?? 'pending'), // 슬러그를 enum으로 복원하기 위함.
        orElse: () => WalkRequestStatus.pending,
      ),
      duration: data['duration'] ?? 30,
      budget: data['budget']?.toDouble(),
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(), // 회귀에 안전하도록 기본값을 둔다.
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(), // 같은 이유로 기본값을 둔다.
    );
  }

  // 쿼리와 인덱스에 친화적인 스키마를 유지하려고 슬러그와 Timestamp로 저장한다.
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

  // 변경 이력을 추적하고 불변성을 유지하려고 부분 갱신용 사본을 생성한다.
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
