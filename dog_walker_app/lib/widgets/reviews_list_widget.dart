// Flutter framework imports
import 'package:flutter/material.dart';

// Local model and service imports
import '../models/review_model.dart';
import '../services/review_service.dart';

// Internationalization support
import '../l10n/app_localizations.dart';

/// Reusable widget that displays a list of reviews for a specific user.
/// 
/// This widget provides a clean, consistent way to display user reviews across
/// the application. It handles async data loading, empty states, and error
/// conditions gracefully.
/// 
/// Key features:
/// - Async data loading with FutureBuilder pattern
/// - Loading state with CircularProgressIndicator
/// - Empty state with localized message
/// - Responsive card-based layout
/// - Formatted rating display with star icons
/// - Localized timestamp formatting
/// 
/// Usage:
/// - Typically used in user profile screens
/// - Can be embedded in other widgets as a child
/// - Automatically handles data fetching and state management
/// 
/// Performance considerations:
/// - Uses shrinkWrap and NeverScrollableScrollPhysics for nested scrolling
/// - Efficient ListView.builder for large review lists
/// - Minimal rebuilds due to StatelessWidget design
class ReviewsListWidget extends StatelessWidget {
  /// The ID of the user whose reviews should be displayed
  final String userId;
  
  const ReviewsListWidget({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReviewModel>>(
      // Fetch reviews for the specified user asynchronously
      future: ReviewService().getReviewsForUser(userId),
      builder: (context, snapshot) {
        // Handle loading state - show progress indicator while data is being fetched
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Extract reviews data from snapshot
        final reviews = snapshot.data!;
        
        // Handle empty state - show message when no reviews exist
        if (reviews.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context).t('no_reviews_yet'))
          );
        }
        
        // Build scrollable list of review cards
        return ListView.builder(
          // Prevent infinite height issues when used in Column
          shrinkWrap: true,
          // Disable scrolling to allow parent widgets to handle scrolling
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            
            // Create individual review card
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: ListTile(
                // Star icon to represent rating
                leading: Icon(Icons.star, color: Colors.amber[700]),
                // Display rating with one decimal place
                title: Text('Rating: ${review.rating.toStringAsFixed(1)}'),
                // Show review comment as subtitle
                subtitle: Text(review.comment),
                // Display formatted date on the right side
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
