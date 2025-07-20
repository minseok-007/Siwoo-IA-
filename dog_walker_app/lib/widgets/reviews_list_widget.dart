import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';

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
          return const Center(child: Text('No reviews yet.'));
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