import 'package:cloud_firestore/cloud_firestore.dart';

class DogModel {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final int age;
  final String? photoUrl;
  final String? notes;

  DogModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.age,
    this.photoUrl,
    this.notes,
  });

  factory DogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DogModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      age: data['age'] ?? 0,
      photoUrl: data['photoUrl'],
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'age': age,
      'photoUrl': photoUrl,
      'notes': notes,
    };
  }
} 