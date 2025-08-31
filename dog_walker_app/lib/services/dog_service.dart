import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dog_model.dart';

/// 강아지 컬렉션에 대한 CRUD 전용 서비스.
/// - Firestore 접근 로직을 캡슐화하여 상위 레이어(UI/Provider)가 단순해집니다.
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
