import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

class ReviewService {
  final CollectionReference reviewsCollection = FirebaseFirestore.instance.collection('reviews');

  Future<void> addReview(ReviewModel review) async {
    await reviewsCollection.doc(review.id).set(review.toFirestore());
  }

  Future<List<ReviewModel>> getReviewsForUser(String userId) async {
    final query = await reviewsCollection.where('revieweeId', isEqualTo: userId).get();
    return query.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
  }

  Future<double> getAverageRating(String userId) async {
    final reviews = await getReviewsForUser(userId);
    if (reviews.isEmpty) return 0.0;
    final total = reviews.fold(0.0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }
} 