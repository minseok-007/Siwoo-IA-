/* 요약: 역할 기반 매칭과 권한 분리를 명확히 하기 위해 사용자 정보를
   독립 모델로 둔다. WHAT/HOW: Firestore 스키마와 일관 매핑, enum/불변으로 안정성 확보. */
import 'package:cloud_firestore/cloud_firestore.dart';

// 권한과 기능 분기를 명확히 하려는 의도로 역할을 enum으로 정의한다.
/// 사용자 유형을 구분 (도그 오너/도그 워커).
enum UserType { dogOwner, dogWalker }

// 매칭 필터 기준을 표준화하려는 의도로 강아지 크기를 enum으로 정의한다.
/// 강아지 크기: 매칭/필터에 사용.
enum DogSize { small, medium, large }

// 가격과 품질 기대치를 산정하려는 의도로 경험 단계를 enum으로 구분한다.
/// 워커 경험 수준: 매칭 가중치에 반영.
enum ExperienceLevel { beginner, intermediate, expert }

// 화면과 서비스를 분리하고 단일 진실 소스를 유지하려고 도메인 모델로 관리한다.
/// 사용자 도메인 모델.
/// - Firestore 연동을 고려해 DateTime/GeoPoint 등 적절한 타입을 선택했습니다.
/// - final로 불변성을 유지하여 상태 관리 시 예측 가능성을 확보합니다.
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserType userType;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 매칭 및 추천 품질을 위한 확장 속성들
  final GeoPoint? location; // Firestore GeoPoint 사용: 위경도 연산/저장에 최적화
  final List<DogSize> preferredDogSizes; // 워커가 선호하는 강아지 크기
  final List<DogSize> dogSizes; // 오너(보유 강아지)의 크기 목록
  final ExperienceLevel experienceLevel; // 워커의 경험 수준
  final double hourlyRate; // 워커의 시급 (원/달러 등 단위는 UI에서 표시)
  final List<String> preferredTimeSlots; // 예: ["morning", "afternoon", "evening"]
  final List<int> availableDays; // 0=Sun, 1=Mon ... 요일 인덱스
  final double maxDistance; // 이동 가능 최대 거리(km)
  final double rating; // 평균 평점 (0~5)
  final int totalWalks; // 총 산책 수 (신뢰도 지표)
  final List<String> specializations; // 특화 분야(퍼피/시니어/리액티브 등)

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.userType,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
    this.location,
    this.preferredDogSizes = const [],
    this.dogSizes = const [],
    this.experienceLevel = ExperienceLevel.beginner,
    this.hourlyRate = 0.0,
    this.preferredTimeSlots = const [],
    this.availableDays = const [],
    this.maxDistance = 10.0,
    this.rating = 0.0,
    this.totalWalks = 0,
    this.specializations = const [],
  });

  // 외부 저장소에서 타입을 안전하게 복원하려고 enum과 리스트를 방어적으로 변환한다.
  /// Firestore 문서 → UserModel 변환 로직.
  /// - enum 복원, 리스트 캐스팅, 숫자(Double) 안전 변환을 처리합니다.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      userType: UserType.values.firstWhere(
        (e) => e.toString() == 'UserType.${data['userType']}',
        orElse: () => UserType.dogOwner,
      ),
      profileImageUrl: data['profileImageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(), // 서버 시각과 동기화를 유지하기 위함.
      updatedAt: (data['updatedAt'] as Timestamp).toDate(), // 변경 이력의 근거를 남기기 위함.
      location: data['location'],
      preferredDogSizes: (data['preferredDogSizes'] as List<dynamic>?)
          ?.map((e) => DogSize.values.firstWhere(
                (size) => size.toString() == 'DogSize.$e', // 슬러그 문자열을 enum으로 복원하기 위함.
                orElse: () => DogSize.medium,
              ))
          .toList() ?? [],
      dogSizes: (data['dogSizes'] as List<dynamic>?)
          ?.map((e) => DogSize.values.firstWhere(
                (size) => size.toString() == 'DogSize.$e', // 동일 방식으로 슬러그를 enum으로 복원한다.
                orElse: () => DogSize.medium,
              ))
          .toList() ?? [],
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) => e.toString() == 'ExperienceLevel.${data['experienceLevel']}', // 슬러그를 enum으로 동일 방식으로 복원한다.
        orElse: () => ExperienceLevel.beginner,
      ),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      preferredTimeSlots: List<String>.from(data['preferredTimeSlots'] ?? []),
      availableDays: List<int>.from(data['availableDays'] ?? []),
      maxDistance: (data['maxDistance'] ?? 10.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalWalks: data['totalWalks'] ?? 0,
      specializations: List<String>.from(data['specializations'] ?? []),
    );
  }

  // 쿼리와 인덱싱을 단순화하려는 의도로 enum 슬러그와 Timestamp를 사용한다.
  /// UserModel → Firestore 저장 Map.
  /// - enum은 슬러그만 저장하여 쿼리 및 가독성을 높입니다.
  /// - DateTime은 Timestamp로 변환합니다.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'userType': userType.toString().split('.').last,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'location': location,
      'preferredDogSizes': preferredDogSizes.map((e) => e.toString().split('.').last).toList(),
      'dogSizes': dogSizes.map((e) => e.toString().split('.').last).toList(),
      'experienceLevel': experienceLevel.toString().split('.').last,
      'hourlyRate': hourlyRate,
      'preferredTimeSlots': preferredTimeSlots,
      'availableDays': availableDays,
      'maxDistance': maxDistance,
      'rating': rating,
      'totalWalks': totalWalks,
      'specializations': specializations,
    };
  }

  // 상태를 불변으로 유지하면서 변경 사항만 반영하려고 사본 패턴을 사용한다.
  /// copyWith 패턴으로 부분 업데이트를 간결하게 지원합니다.
  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserType? userType,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    GeoPoint? location,
    List<DogSize>? preferredDogSizes,
    List<DogSize>? dogSizes,
    ExperienceLevel? experienceLevel,
    double? hourlyRate,
    List<String>? preferredTimeSlots,
    List<int>? availableDays,
    double? maxDistance,
    double? rating,
    int? totalWalks,
    List<String>? specializations,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType ?? this.userType,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location ?? this.location,
      preferredDogSizes: preferredDogSizes ?? this.preferredDogSizes,
      dogSizes: dogSizes ?? this.dogSizes,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      preferredTimeSlots: preferredTimeSlots ?? this.preferredTimeSlots,
      availableDays: availableDays ?? this.availableDays,
      maxDistance: maxDistance ?? this.maxDistance,
      rating: rating ?? this.rating,
      totalWalks: totalWalks ?? this.totalWalks,
      specializations: specializations ?? this.specializations,
    );
  }
} 
