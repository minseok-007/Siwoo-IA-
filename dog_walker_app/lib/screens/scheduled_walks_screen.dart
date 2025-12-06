import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../models/user_model.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';
import 'review_form_screen.dart';
import '../services/review_service.dart';
import '../l10n/app_localizations.dart';

/// Schedule view for walkers.
/// - Lists accepted/completed walks and links into chats with owners.
class ScheduledWalksScreen extends StatefulWidget {
  const ScheduledWalksScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledWalksScreen> createState() => _ScheduledWalksScreenState();
}

class _ScheduledWalksScreenState extends State<ScheduledWalksScreen> {
  final WalkRequestService _walkService = WalkRequestService();
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  List<WalkRequestModel> _scheduledWalks = [];
  bool _loading = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _fetchScheduledWalks();
  }

  Future<void> _fetchScheduledWalks() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    if (currentUserId == null) return;

    try {
      final now = DateTime.now();
      final walks = await _walkService.getRequestsByWalker(currentUserId);
      
      // Filter: only future walks with accepted or completed status
      final futureWalks = walks
          .where(
            (walk) =>
                (walk.status == WalkRequestStatus.accepted ||
                 walk.status == WalkRequestStatus.completed) &&
                walk.startTime.isAfter(now),
          )
          .toList();
      
      // Sort by start time (ascending - earliest first)
      futureWalks.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      setState(() {
        _scheduledWalks = futureWalks;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('err_loading_scheduled')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _startChat(WalkRequestModel walk) async {
    try {
      final owner = await _userService.getUserById(walk.ownerId);
      if (owner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('owner_not_found')),
          ),
        );
        return;
      }

      // Create a unique chat ID based on walk request and participants
      final chatId = 'walk_${walk.id}_${walk.ownerId}_${walk.walkerId ?? ''}';
      final currentUserId =
          Provider.of<AuthProvider>(context, listen: false).currentUserId;
      final chatUserId = currentUserId ?? walk.walkerId;
      if (chatUserId == null || chatUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t('user_not_authenticated'),
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            userId: chatUserId,
            otherUserName: owner.fullName,
            otherUserId: owner.id,
            walkRequest: walk,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('err_start_chat')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _markCompletedAndPromptReview(WalkRequestModel walk) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      // Mark as completed
      final updated = walk.copyWith(status: WalkRequestStatus.completed);
      await _walkService.updateWalkRequest(updated);

      // Refresh list
      await _fetchScheduledWalks();

      // Current user (walker in this screen)
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final reviewerId = auth.currentUserId ?? '';
      if (reviewerId.isEmpty) {
        setState(() => _processing = false);
        return;
      }

      // Prevent duplicate review for this walk by this reviewer
      final already = await _reviewService.hasReview(
        reviewerId: reviewerId,
        walkId: walk.id,
      );

      if (!already) {
        // Reviewee is the owner when walker leaves a review from schedule
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewFormScreen(
              reviewerId: reviewerId,
              revieweeId: walk.ownerId,
              walkId: walk.id,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing walk: $e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${AppLocalizations.of(context).t('at')} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(WalkRequestStatus status) {
    switch (status) {
      case WalkRequestStatus.accepted:
        return Colors.green;
      case WalkRequestStatus.completed:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('my_scheduled_walks')),
        backgroundColor: Colors.blue[600],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchScheduledWalks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scheduledWalks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.t('no_scheduled_walks'),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.t('accept_walks_hint'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _scheduledWalks.length,
              itemBuilder: (context, index) {
                final walk = _scheduledWalks[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_walk,
                              color: Colors.blue[600],
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    walk.location,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDateTime(walk.startTime),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(walk.status!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                walk.status
                                    .toString()
                                    .split('.')
                                    .last
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (walk.notes != null && walk.notes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${t.t('notes')}: ${walk.notes}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _startChat(walk),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(t.t('chat_with_owner')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (walk.status == WalkRequestStatus.accepted)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _markCompletedAndPromptReview(walk),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(t.t('mark_complete')),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green[600],
                                    side: BorderSide(color: Colors.green[600]!),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
