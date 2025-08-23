import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { dogOwner, dogWalker }

enum DogSize { small, medium, large }

enum ExperienceLevel { beginner, intermediate, expert }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserType userType;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Advanced matching preferences
  final GeoPoint? location; // Firestore GeoPoint
  final List<DogSize> preferredDogSizes; // For walkers
  final List<DogSize> dogSizes; // For owners (their dogs' sizes)
  final ExperienceLevel experienceLevel; // For walkers
  final double hourlyRate; // For walkers
  final List<String> preferredTimeSlots; // e.g., ["morning", "afternoon", "evening"]
  final List<int> availableDays; // 0=Sunday, 1=Monday, etc.
  final double maxDistance; // Maximum distance willing to travel (km)
  final double rating; // Average rating
  final int totalWalks; // Total walks completed
  final List<String> specializations; // e.g., ["puppy", "senior", "reactive"]

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
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      location: data['location'],
      preferredDogSizes: (data['preferredDogSizes'] as List<dynamic>?)
          ?.map((e) => DogSize.values.firstWhere(
                (size) => size.toString() == 'DogSize.$e',
                orElse: () => DogSize.medium,
              ))
          .toList() ?? [],
      dogSizes: (data['dogSizes'] as List<dynamic>?)
          ?.map((e) => DogSize.values.firstWhere(
                (size) => size.toString() == 'DogSize.$e',
                orElse: () => DogSize.medium,
              ))
          .toList() ?? [],
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) => e.toString() == 'ExperienceLevel.${data['experienceLevel']}',
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