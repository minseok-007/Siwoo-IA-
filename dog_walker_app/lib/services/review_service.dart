import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';

/// 리뷰(reviews) 컬렉션에 대한 CRUD/쿼리 서비스.
/// - 평균 평점 계산 유틸도 함께 제공합니다.
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
