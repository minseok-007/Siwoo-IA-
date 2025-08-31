import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

/// 강아지 성향을 표현하는 열거형.
/// enum을 사용하면 문자열 오타를 줄이고, 타입 안전하게 비교/저장이 가능합니다.
enum DogTemperament { calm, friendly, energetic, shy, aggressive, reactive }

/// 에너지 레벨 (산책/활동량 매칭에 활용).
enum EnergyLevel { low, medium, high, veryHigh }

/// 특이사항(케어 필요)을 나타내는 타입. 목록으로 복수 선택을 허용합니다.
enum SpecialNeeds { none, medication, elderly, puppy, training, socializing }

/// 강아지 도메인 모델.
/// - 모든 필드는 불변(final)로 유지해서 데이터 일관성과 예측 가능성을 높였습니다.
/// - Firestore 저장 시에는 Dart의 타입을 그대로 쓰고, 직렬화 시에만 적절히 변환합니다.
class DogModel {
  final String id;
  final String name;
  final String breed;
  final int age;
  final String ownerId;
  final String? profileImageUrl;
  final String? description;
  final DateTime createdAt; // Firestore Timestamp ↔️ DateTime 변환 사용
  final DateTime updatedAt; // 클라이언트-서버 간 직렬화에 용이
  
  // 매칭 품질을 높이기 위한 속성들
  final DogSize size;
  final DogTemperament temperament;
  final EnergyLevel energyLevel;
  final List<SpecialNeeds> specialNeeds; // enum 리스트로 안전하게 표현
  final double weight; // kg 단위. double로 소수 허용
  final bool isNeutered; // 중성화 여부는 boolean이 가장 명확
  final List<String> medicalConditions; // 문자열 목록: 확장/검색 용이
  final List<String> trainingCommands; // 예: ["sit", "stay", "come"]
  final bool isGoodWithOtherDogs;
  final bool isGoodWithChildren;
  final bool isGoodWithStrangers;
  final String? vetContact;
  final String? emergencyContact;

  DogModel({
    required this.id,
    required this.name,
    required this.breed,
    required this.age,
    required this.ownerId,
    this.profileImageUrl,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.size = DogSize.medium,
    this.temperament = DogTemperament.friendly,
    this.energyLevel = EnergyLevel.medium,
    this.specialNeeds = const [],
    this.weight = 0.0,
    this.isNeutered = false,
    this.medicalConditions = const [],
    this.trainingCommands = const [],
    this.isGoodWithOtherDogs = true,
    this.isGoodWithChildren = true,
    this.isGoodWithStrangers = true,
    this.vetContact,
    this.emergencyContact,
  });

  /// Firestore 문서를 안전하게 앱 도메인 모델로 변환합니다.
  /// - null/타입 오류에 대비해 널 병합/기본값을 제공합니다.
  /// - enum은 저장 시 소문자 키워드만 저장하므로 toString 분해로 복원합니다.
  factory DogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DogModel(
      id: doc.id,
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      age: data['age'] ?? 0,
      ownerId: data['ownerId'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(), // Timestamp → DateTime
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      size: DogSize.values.firstWhere(
        (e) => e.toString() == 'DogSize.${data['size']}',
        orElse: () => DogSize.medium,
      ),
      temperament: DogTemperament.values.firstWhere(
        (e) => e.toString() == 'DogTemperament.${data['temperament']}',
        orElse: () => DogTemperament.friendly,
      ),
      energyLevel: EnergyLevel.values.firstWhere(
        (e) => e.toString() == 'EnergyLevel.${data['energyLevel']}',
        orElse: () => EnergyLevel.medium,
      ),
      specialNeeds: (data['specialNeeds'] as List<dynamic>?)
          ?.map((e) => SpecialNeeds.values.firstWhere(
                (need) => need.toString() == 'SpecialNeeds.$e',
                orElse: () => SpecialNeeds.none,
              ))
          .toList() ?? [],
      weight: (data['weight'] ?? 0.0).toDouble(),
      isNeutered: data['isNeutered'] ?? false,
      medicalConditions: List<String>.from(data['medicalConditions'] ?? []),
      trainingCommands: List<String>.from(data['trainingCommands'] ?? []),
      isGoodWithOtherDogs: data['isGoodWithOtherDogs'] ?? true,
      isGoodWithChildren: data['isGoodWithChildren'] ?? true,
      isGoodWithStrangers: data['isGoodWithStrangers'] ?? true,
      vetContact: data['vetContact'],
      emergencyContact: data['emergencyContact'],
    );
  }

  /// 앱 모델을 Firestore에 저장 가능한 Map으로 변환합니다.
  /// - enum은 `split('.')`로 슬러그만 저장해 쿼리/인덱싱 시 가독성을 높입니다.
  /// - DateTime은 Firestore가 권장하는 Timestamp로 변환합니다.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'breed': breed,
      'age': age,
      'ownerId': ownerId,
      'profileImageUrl': profileImageUrl,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'size': size.toString().split('.').last,
      'temperament': temperament.toString().split('.').last,
      'energyLevel': energyLevel.toString().split('.').last,
      'specialNeeds': specialNeeds.map((e) => e.toString().split('.').last).toList(),
      'weight': weight,
      'isNeutered': isNeutered,
      'medicalConditions': medicalConditions,
      'trainingCommands': trainingCommands,
      'isGoodWithOtherDogs': isGoodWithOtherDogs,
      'isGoodWithChildren': isGoodWithChildren,
      'isGoodWithStrangers': isGoodWithStrangers,
      'vetContact': vetContact,
      'emergencyContact': emergencyContact,
    };
  }

  /// 불변 객체의 편리한 복사를 위한 copyWith 패턴.
  /// - 필요한 필드만 선택적으로 변경할 수 있어 유지보수성과 테스트 용이성이 높습니다.
  DogModel copyWith({
    String? id,
    String? name,
    String? breed,
    int? age,
    String? ownerId,
    String? profileImageUrl,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DogSize? size,
    DogTemperament? temperament,
    EnergyLevel? energyLevel,
    List<SpecialNeeds>? specialNeeds,
    double? weight,
    bool? isNeutered,
    List<String>? medicalConditions,
    List<String>? trainingCommands,
    bool? isGoodWithOtherDogs,
    bool? isGoodWithChildren,
    bool? isGoodWithStrangers,
    String? vetContact,
    String? emergencyContact,
  }) {
    return DogModel(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      ownerId: ownerId ?? this.ownerId,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      size: size ?? this.size,
      temperament: temperament ?? this.temperament,
      energyLevel: energyLevel ?? this.energyLevel,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      weight: weight ?? this.weight,
      isNeutered: isNeutered ?? this.isNeutered,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      trainingCommands: trainingCommands ?? this.trainingCommands,
      isGoodWithOtherDogs: isGoodWithOtherDogs ?? this.isGoodWithOtherDogs,
      isGoodWithChildren: isGoodWithChildren ?? this.isGoodWithChildren,
      isGoodWithStrangers: isGoodWithStrangers ?? this.isGoodWithStrangers,
      vetContact: vetContact ?? this.vetContact,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }
} 
