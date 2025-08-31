import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../l10n/app_localizations.dart';

/// 리뷰 작성 화면.
/// - 산책 완료 후 상대방에 대한 평점/코멘트를 수집합니다.
class ReviewFormScreen extends StatefulWidget {
  final String reviewerId;
  final String revieweeId;
  final String walkId;
  const ReviewFormScreen({Key? key, required this.reviewerId, required this.revieweeId, required this.walkId}) : super(key: key);

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  final _formKey = GlobalKey<FormState>();
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _saving = false;

  Future<void> _saveReview() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final review = ReviewModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      reviewerId: widget.reviewerId,
      revieweeId: widget.revieweeId,
      walkId: widget.walkId,
      rating: _rating,
      comment: _commentController.text.trim(),
      timestamp: DateTime.now(),
    );
    await ReviewService().addReview(review);
    setState(() => _saving = false);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('leave_a_review')),
        backgroundColor: Colors.amber[700],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(t.t('rate_your_experience'), style: TextStyle(fontSize: 18, color: Colors.amber[900])),
              Slider(
                value: _rating,
                min: 1,
                max: 5,
                divisions: 4,
                label: _rating.toString(),
                onChanged: (v) => setState(() => _rating = v),
              ),
              TextFormField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: t.t('comment'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.comment),
                ),
                maxLines: 3,
                validator: (v) => v == null || v.trim().isEmpty ? t.t('comment_required') : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saving ? null : _saveReview,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(t.t('submit_review')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
