import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { dogOwner, dogWalker }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserType userType;
  final String? profileImageUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Dog Owner specific fields
  final List<String>? dogIds;
  final String? address;
  
  // Dog Walker specific fields
  final List<String>? experience;
  final double? hourlyRate;
  final List<String>? availableDays;
  final List<String>? availableTimes;
  final bool? isVerified;
  final double? rating;
  final int? totalWalks;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.userType,
    this.profileImageUrl,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
    this.dogIds,
    this.address,
    this.experience,
    this.hourlyRate,
    this.availableDays,
    this.availableTimes,
    this.isVerified,
    this.rating,
    this.totalWalks,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      userType: data['userType'] == 'dogOwner' ? UserType.dogOwner : UserType.dogWalker,
      profileImageUrl: data['profileImageUrl'],
      bio: data['bio'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      dogIds: data['dogIds'] != null ? List<String>.from(data['dogIds']) : null,
      address: data['address'],
      experience: data['experience'] != null ? List<String>.from(data['experience']) : null,
      hourlyRate: data['hourlyRate']?.toDouble(),
      availableDays: data['availableDays'] != null ? List<String>.from(data['availableDays']) : null,
      availableTimes: data['availableTimes'] != null ? List<String>.from(data['availableTimes']) : null,
      isVerified: data['isVerified'] ?? false,
      rating: data['rating']?.toDouble(),
      totalWalks: data['totalWalks'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'userType': userType == UserType.dogOwner ? 'dogOwner' : 'dogWalker',
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'dogIds': dogIds,
      'address': address,
      'experience': experience,
      'hourlyRate': hourlyRate,
      'availableDays': availableDays,
      'availableTimes': availableTimes,
      'isVerified': isVerified,
      'rating': rating,
      'totalWalks': totalWalks,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserType? userType,
    String? profileImageUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? dogIds,
    String? address,
    List<String>? experience,
    double? hourlyRate,
    List<String>? availableDays,
    List<String>? availableTimes,
    bool? isVerified,
    double? rating,
    int? totalWalks,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType ?? this.userType,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dogIds: dogIds ?? this.dogIds,
      address: address ?? this.address,
      experience: experience ?? this.experience,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      availableDays: availableDays ?? this.availableDays,
      availableTimes: availableTimes ?? this.availableTimes,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      totalWalks: totalWalks ?? this.totalWalks,
    );
  }
} 