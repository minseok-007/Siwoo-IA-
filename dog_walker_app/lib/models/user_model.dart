/* Summary: Keep user data in a dedicated model to clearly separate roles and permissions
   for matching. WHAT/HOW: Map directly to the Firestore schema while using enums and
   immutability for stability. */
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dog_traits.dart';

// Define roles as enums so permission-driven logic stays explicit.
/// Distinguishes user types (dog owner vs walker).
enum UserType { dogOwner, dogWalker }

// Encode dog size as an enum to standardize matching filters.
/// Dog size enum used for matching/filter logic.
enum DogSize { small, medium, large }

// Split experience levels into enums to calibrate pricing/quality expectations.
/// Walker experience tiers; used in matching weights.
enum ExperienceLevel { beginner, intermediate, expert }

// Manage users as a domain model to decouple UI and services with a single source of truth.
/// User domain model.
/// - Chooses Firestore-friendly types like DateTime/GeoPoint.
/// - Keeps fields `final` to make state management predictable.
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserType userType;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Extended attributes that improve match quality and recommendations
  final GeoPoint? location; // Firestore GeoPoint: optimized for storing lat/lng
  final List<DogSize> preferredDogSizes; // Sizes a walker prefers
  final List<DogSize> dogSizes; // Sizes of the owner's dogs
  final ExperienceLevel experienceLevel; // Walker experience level
  final List<String>
  preferredTimeSlots; // e.g. ["morning", "afternoon", "evening"]
  final List<int> availableDays; // 0=Sun, 1=Mon ... weekday indices
  final double maxDistance; // Max travel distance (km)
  final double rating; // Average rating (0–5)
  final int totalWalks; // Total walks (trust signal)
  final List<String>
  specializations; // Specialties (puppy/senior/reactive, etc.)
  final List<DogTemperament>
  preferredTemperaments; // Temperaments the walker is comfortable with
  final List<EnergyLevel>
  preferredEnergyLevels; // Energy levels the walker handles
  final List<SpecialNeeds>
  supportedSpecialNeeds; // Special needs the walker can manage

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
    this.preferredTimeSlots = const [],
    this.availableDays = const [],
    this.maxDistance = 10.0,
    this.rating = 0.0,
    this.totalWalks = 0,
    this.specializations = const [],
    this.preferredTemperaments = const [],
    this.preferredEnergyLevels = const [],
    this.supportedSpecialNeeds = const [],
  });

  // Restore enums and lists defensively when rebuilding from external storage.
  /// Firestore document → UserModel conversion logic.
  /// - Handles enum reconstruction, list casting, and safe numeric conversion.
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
      createdAt: (data['createdAt'] as Timestamp)
          .toDate(), // Keeps parity with server timestamps
      updatedAt: (data['updatedAt'] as Timestamp)
          .toDate(), // Preserves auditability for changes
      location: data['location'],
      preferredDogSizes:
          (data['preferredDogSizes'] as List<dynamic>?)
              ?.map(
                (e) => DogSize.values.firstWhere(
                  (size) =>
                      size.toString() ==
                      'DogSize.$e', // Rehydrate enum from stored slug
                  orElse: () => DogSize.medium,
                ),
              )
              .toList() ??
          [],
      dogSizes:
          (data['dogSizes'] as List<dynamic>?)
              ?.map(
                (e) => DogSize.values.firstWhere(
                  (size) =>
                      size.toString() ==
                      'DogSize.$e', // Same slug→enum restoration
                  orElse: () => DogSize.medium,
                ),
              )
              .toList() ??
          [],
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) =>
            e.toString() ==
            'ExperienceLevel.${data['experienceLevel']}', // Same slug→enum restoration
        orElse: () => ExperienceLevel.beginner,
      ),
      preferredTimeSlots: List<String>.from(data['preferredTimeSlots'] ?? []),
      availableDays: List<int>.from(data['availableDays'] ?? []),
      maxDistance: (data['maxDistance'] ?? 10.0).toDouble(),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalWalks: data['totalWalks'] ?? 0,
      specializations: List<String>.from(data['specializations'] ?? []),
      preferredTemperaments:
          (data['preferredTemperaments'] as List<dynamic>?)
              ?.map(
                (e) => DogTemperament.values.firstWhere(
                  (temp) => temp.toString().split('.').last == e,
                  orElse: () => DogTemperament.friendly,
                ),
              )
              .toList() ??
          [],
      preferredEnergyLevels:
          (data['preferredEnergyLevels'] as List<dynamic>?)
              ?.map(
                (e) => EnergyLevel.values.firstWhere(
                  (level) => level.toString().split('.').last == e,
                  orElse: () => EnergyLevel.medium,
                ),
              )
              .toList() ??
          [],
      supportedSpecialNeeds:
          (data['supportedSpecialNeeds'] as List<dynamic>?)
              ?.map(
                (e) => SpecialNeeds.values.firstWhere(
                  (need) => need.toString().split('.').last == e,
                  orElse: () => SpecialNeeds.none,
                ),
              )
              .toList() ??
          [],
    );
  }

  // Use enum slugs and Timestamps to simplify queries and indexing.
  /// Serializes a UserModel into a Firestore-ready map.
  /// - Store slug values for enums to improve readability and querying.
  /// - Convert DateTime values to Timestamps.
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
      'preferredDogSizes': preferredDogSizes
          .map((e) => e.toString().split('.').last)
          .toList(),
      'dogSizes': dogSizes.map((e) => e.toString().split('.').last).toList(),
      'experienceLevel': experienceLevel.toString().split('.').last,
      'preferredTimeSlots': preferredTimeSlots,
      'availableDays': availableDays,
      'maxDistance': maxDistance,
      'rating': rating,
      'totalWalks': totalWalks,
      'specializations': specializations,
      'preferredTemperaments': preferredTemperaments
          .map((e) => e.toString().split('.').last)
          .toList(),
      'preferredEnergyLevels': preferredEnergyLevels
          .map((e) => e.toString().split('.').last)
          .toList(),
      'supportedSpecialNeeds': supportedSpecialNeeds
          .map((e) => e.toString().split('.').last)
          .toList(),
    };
  }

  // Provide a copy pattern to reflect changes while keeping the model immutable.
  /// Offers a convenient `copyWith` for partial updates.
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
    List<String>? preferredTimeSlots,
    List<int>? availableDays,
    double? maxDistance,
    double? rating,
    int? totalWalks,
    List<String>? specializations,
    List<DogTemperament>? preferredTemperaments,
    List<EnergyLevel>? preferredEnergyLevels,
    List<SpecialNeeds>? supportedSpecialNeeds,
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
      preferredTimeSlots: preferredTimeSlots ?? this.preferredTimeSlots,
      availableDays: availableDays ?? this.availableDays,
      maxDistance: maxDistance ?? this.maxDistance,
      rating: rating ?? this.rating,
      totalWalks: totalWalks ?? this.totalWalks,
      specializations: specializations ?? this.specializations,
      preferredTemperaments:
          preferredTemperaments ?? this.preferredTemperaments,
      preferredEnergyLevels:
          preferredEnergyLevels ?? this.preferredEnergyLevels,
      supportedSpecialNeeds:
          supportedSpecialNeeds ?? this.supportedSpecialNeeds,
    );
  }
}
