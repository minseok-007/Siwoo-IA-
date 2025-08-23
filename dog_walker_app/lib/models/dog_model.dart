import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum DogTemperament { calm, friendly, energetic, shy, aggressive, reactive }
enum EnergyLevel { low, medium, high, veryHigh }
enum SpecialNeeds { none, medication, elderly, puppy, training, socializing }

class DogModel {
  final String id;
  final String name;
  final String breed;
  final int age;
  final String ownerId;
  final String? profileImageUrl;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Advanced matching characteristics
  final DogSize size;
  final DogTemperament temperament;
  final EnergyLevel energyLevel;
  final List<SpecialNeeds> specialNeeds;
  final double weight; // in kg
  final bool isNeutered;
  final List<String> medicalConditions;
  final List<String> trainingCommands; // e.g., ["sit", "stay", "come"]
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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
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