import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dog_model.dart';

class DogService {
  final CollectionReference dogsCollection = FirebaseFirestore.instance.collection('dogs');

  Future<void> addDog(DogModel dog) async {
    await dogsCollection.doc(dog.id).set(dog.toFirestore());
  }

  Future<void> updateDog(DogModel dog) async {
    await dogsCollection.doc(dog.id).update(dog.toFirestore());
  }

  Future<void> deleteDog(String dogId) async {
    await dogsCollection.doc(dogId).delete();
  }

  Future<List<DogModel>> getDogsByOwner(String ownerId) async {
    final query = await dogsCollection.where('ownerId', isEqualTo: ownerId).get();
    return query.docs.map((doc) => DogModel.fromFirestore(doc)).toList();
  }

  Future<DogModel?> getDogById(String dogId) async {
    final doc = await dogsCollection.doc(dogId).get();
    if (doc.exists) {
      return DogModel.fromFirestore(doc);
    }
    return null;
  }
} 