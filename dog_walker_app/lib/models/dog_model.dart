/* Summary: To prioritize matching quality and data consistency, dog information is
   modeled as a dedicated domain object. WHAT/HOW: Maintain a 1:1 mapping with the
   Firestore schema while leveraging enums and immutable fields to boost type safety
   and maintainability. */
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

// Normalize temperament so matching/filter logic stays simple and type-safe.
/// Enumeration representing a dog's temperament.
/// Using enums reduces string typos and keeps comparisons/storage type-safe.
enum DogTemperament { calm, friendly, energetic, shy, aggressive, reactive }

// Define clear energy tiers for activity-based recommendations and pricing.
/// Energy level (used for walk/activity matching).
enum EnergyLevel { low, medium, high, veryHigh }

// Predefine special-care scenarios to simplify branching logic.
/// Represents special care needs; allow multiple selections via a list.
enum SpecialNeeds { none, medication, elderly, puppy, training, socializing }

// Centralize dog data into a domain model to decouple screens and services.
/// Dog domain model.
/// - Keep fields immutable (`final`) to preserve consistency and predictability.
/// - Persist native Dart types and transform only during serialization for Firestore.
class DogModel {
  final String id;
  final String name;
  final String breed;
  final int age;
  final String ownerId;
  final String? profileImageUrl;
  final String? description;
  final DateTime createdAt; // Uses Firestore Timestamp ↔️ DateTime conversion
  final DateTime updatedAt; // Keeps client/server serialization straightforward

  // Attributes that improve matching quality
  final DogSize size;
  final DogTemperament temperament;
  final EnergyLevel energyLevel;
  final List<SpecialNeeds> specialNeeds; // Represented as an enum list for safety
  final double weight; // Kilograms; double to allow decimals
  final bool isNeutered; // Boolean communicates neutering status clearly
  final List<String> medicalConditions; // String list keeps expansion/search simple
  final List<String> trainingCommands; // Example: ["sit", "stay", "come"]
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

  // Apply defensive parsing with defaults to safely restore from the Firestore schema.
  /// Converts a Firestore document into the app's domain model safely.
  /// - Provide null-coalescing/defaults to guard against missing or mistyped data.
  /// - Enums are stored as lowercase slugs, so reconstruct them from `toString` values.
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
      createdAt: (data['createdAt'] as Timestamp).toDate(), // Keeps parity with server timestamps
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      size: DogSize.values.firstWhere(
        (e) => e.toString() == 'DogSize.${data['size']}', // Rebuild enum from stored slug
        orElse: () => DogSize.medium,
      ),
      temperament: DogTemperament.values.firstWhere(
        (e) => e.toString() == 'DogTemperament.${data['temperament']}', // Same slug→enum restoration
        orElse: () => DogTemperament.friendly,
      ),
      energyLevel: EnergyLevel.values.firstWhere(
        (e) => e.toString() == 'EnergyLevel.${data['energyLevel']}', // Same slug→enum restoration
        orElse: () => EnergyLevel.medium,
      ),
      specialNeeds: (data['specialNeeds'] as List<dynamic>?)
          ?.map((e) => SpecialNeeds.values.firstWhere(
                (need) => need.toString() == 'SpecialNeeds.$e', // Convert each slug back to enum
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

  // Use slugs and Timestamps to simplify indexing/queries and improve portability.
  /// Serializes the app model into a Map suitable for Firestore.
  /// - Store only the slug portion of enums (`split('.')`) for readable queries/indexing.
  /// - Convert DateTime values into Firestore's recommended Timestamp.
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
      'energyLevel': energyLevel.toString().split('.').last, // Store just the slug for clarity
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

  // Provide a safe clone for partial updates of an immutable object.
  /// Implements a `copyWith` pattern for immutable data classes.
  /// - Swap only the fields you need to adjust, aiding maintainability and tests.
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
