import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../l10n/app_localizations.dart';

/// 특정 사용자에 대한 리뷰 목록 위젯.
/// - 내부에서 FutureBuilder를 사용하여 간단히 비동기 데이터를 렌더링합니다.
class ReviewsListWidget extends StatelessWidget {
  final String userId;
  const ReviewsListWidget({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReviewModel>>(
      future: ReviewService().getReviewsForUser(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return Center(child: Text(AppLocalizations.of(context).t('no_reviews_yet')));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: ListTile(
                leading: Icon(Icons.star, color: Colors.amber[700]),
                title: Text('Rating: ${review.rating.toStringAsFixed(1)}'),
                subtitle: Text(review.comment),
                trailing: Text(
                  review.timestamp.toLocal().toString().split(' ')[0],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        );
      },
    );
  }
} 
