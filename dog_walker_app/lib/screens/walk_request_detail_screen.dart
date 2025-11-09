import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import '../services/user_service.dart';
import '../services/dog_service.dart';
import '../models/dog_model.dart';
import '../models/message_model.dart';
import 'chat_screen.dart';
import 'review_form_screen.dart';
import '../services/review_service.dart';
import '../services/notification_service.dart';
import '../services/message_service.dart';
import '../l10n/app_localizations.dart';

/// Walk-request detail screen.
/// - Surfaces role-specific actions: walkers accept, owners cancel/reschedule, etc.
class WalkRequestDetailScreen extends StatefulWidget {
  final WalkRequestModel request;
  final bool isWalker;
  const WalkRequestDetailScreen({
    Key? key,
    required this.request,
    required this.isWalker,
  }) : super(key: key);

  @override
  State<WalkRequestDetailScreen> createState() =>
      _WalkRequestDetailScreenState();
}

class _WalkRequestDetailScreenState extends State<WalkRequestDetailScreen> {
  bool _processing = false;
  late WalkRequestModel _request;
  final WalkRequestService _service = WalkRequestService();
  final UserService _userService = UserService();
  final DogService _dogService = DogService();
  final ReviewService _reviewService = ReviewService();
  final NotificationService _notificationService = NotificationService();
  final MessageService _messageService = MessageService();
  DogModel? _dog;
  bool _loadingDog = true;
  bool _hasLeftReview = false;
  bool _checkingReview = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _loadDog();
    _checkHasLeftReview();
  }

  Future<void> _loadDog() async {
    try {
      final dog = await _dogService.getDogById(_request.dogId);
      if (!mounted) return;
      setState(() {
        _dog = dog;
        _loadingDog = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDog = false;
      });
    }
  }

  Future<void> _checkHasLeftReview() async {
    if (!mounted) return;
    setState(() => _checkingReview = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final reviewerId = auth.currentUserId;
      if (reviewerId == null) return;
      final exists = await _reviewService.hasReview(
        reviewerId: reviewerId,
        walkId: _request.id,
      );
      if (!mounted) return;
      setState(() => _hasLeftReview = exists);
    } finally {
      if (mounted) setState(() => _checkingReview = false);
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _processing = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    if (currentUserId == null) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('user_not_authenticated'),
          ),
        ),
      );
      return;
    }

    try {
      final updated = _request.copyWith(
        status: WalkRequestStatus.accepted,
        walkerId: currentUserId,
      );
      await _service.updateWalkRequest(updated);
      setState(() {
        _request = updated;
        _processing = false;
      });
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('err_accept_request')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => _processing = true);
    final previousWalkerId = _request.walkerId;
    try {
      final updated = _request.copyWith(status: WalkRequestStatus.cancelled);
      await _service.updateWalkRequest(updated);
      setState(() {
        _request = updated;
        _processing = false;
      });
      await _notifyCancellation(previousWalkerId);
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('err_cancel_request')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _rescheduleRequest() async {
    if (_processing) return;

    final t = AppLocalizations.of(context);
    final newStart = await _pickDateTime(
      initial: _request.startTime,
      minDate: DateTime.now(),
    );
    if (newStart == null) return;

    final newEnd = await _pickDateTime(
      initial: _request.endTime,
      minDate: newStart,
    );
    if (newEnd == null) return;

    if (!newEnd.isAfter(newStart)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.t('invalid_end_time'))),
      );
      return;
    }

    final durationMinutes = newEnd.difference(newStart).inMinutes;
    final previousWalkerId = _request.walkerId;

    setState(() => _processing = true);
    try {
      final updated = _request.copyWith(
        startTime: newStart,
        endTime: newEnd,
        duration: durationMinutes,
        updatedAt: DateTime.now(),
      );
      await _service.updateWalkRequest(updated);
      if (!mounted) return;
      setState(() {
        _request = updated;
        _processing = false;
      });

      await _notifyReschedule(previousWalkerId, newStart, newEnd);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t.t('reschedule_success'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.t('err_loading_requests')}: $e'),
        ),
      );
    }
  }

  Future<void> _markCompleted() async {
    setState(() => _processing = true);
    try {
      final updated = _request.copyWith(status: WalkRequestStatus.completed);
      await _service.updateWalkRequest(updated);
      setState(() {
        _request = updated;
        _processing = false;
      });
      await _promptReviewIfNeeded();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing walk: $e'),
        ),
      );
    }
  }

  Future<void> _promptReviewIfNeeded() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final reviewerId = auth.currentUserId;
    if (reviewerId == null) return;

    // If already reviewed this walk, do nothing
    final already = await _reviewService.hasReview(
      reviewerId: reviewerId,
      walkId: _request.id,
    );
    if (already) return;

    // Determine the other participant to review
    String? revieweeId;
    if (widget.isWalker) {
      revieweeId = _request.ownerId;
    } else {
      revieweeId = _request.walkerId;
    }
    if (revieweeId == null || revieweeId.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewFormScreen(
          reviewerId: reviewerId,
          revieweeId: revieweeId!,
          walkId: _request.id,
        ),
      ),
    );
    await _checkHasLeftReview();
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? minDate,
  }) async {
    final initialDate = DateTime(
      initial.year,
      initial.month,
      initial.day,
      initial.hour,
      initial.minute,
    );

    final firstDate = minDate ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _notifyCancellation(String? walkerId) async {
    if (walkerId == null || walkerId.isEmpty) return;
    final t = AppLocalizations.of(context);
    final actorId = Provider.of<AuthProvider>(context, listen: false).currentUserId;
    if (actorId == null) return;
    final body =
        '${t.t('walk_request')} ${t.t('at')} ${_request.location} ${t.t('has_been_cancelled')}';
    await _notificationService.sendNotification(
      userId: walkerId,
      title: t.t('walk_request'),
      body: body,
      relatedId: _request.id,
      type: 'cancellation',
      createdBy: actorId,
    );
    await _sendSystemMessage(
      walkerId: walkerId,
      text: body,
    );
  }

  Future<void> _notifyReschedule(
    String? walkerId,
    DateTime newStart,
    DateTime newEnd,
  ) async {
    if (walkerId == null || walkerId.isEmpty) return;
    final t = AppLocalizations.of(context);
    final actorId = Provider.of<AuthProvider>(context, listen: false).currentUserId;
    if (actorId == null) return;
    final formattedStart = DateFormat('MMM d, h:mm a').format(newStart);
    final formattedEnd = DateFormat('MMM d, h:mm a').format(newEnd);
    final body = t
        .t('reschedule_notification_body')
        .replaceFirst('%s1', formattedStart)
        .replaceFirst('%s2', formattedEnd);

    await _notificationService.sendNotification(
      userId: walkerId,
      title: t.t('reschedule'),
      body: body,
      relatedId: _request.id,
      type: 'reschedule',
      createdBy: actorId,
    );
    await _sendSystemMessage(
      walkerId: walkerId,
      text: body,
    );
  }

  Future<void> _sendSystemMessage({
    required String walkerId,
    required String text,
  }) async {
    final chatId = _buildChatId(walkerId);
    await _messageService.initializeChat(
      chatId,
      ownerId: _request.ownerId,
      walkerId: walkerId,
    );
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final senderId = auth.currentUserId ?? 'system';
    final message = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    );
    await _messageService.sendMessage(message);
  }

  String _buildChatId(String? walkerId) {
    return 'walk_${_request.id}_${_request.ownerId}_${walkerId ?? ''}';
  }

  Future<void> _startChat() async {
    try {
      final authProvider =
          Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUserId;
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t('user_not_authenticated'),
            ),
          ),
        );
        return;
      }

      // Resolve participants for the chat
      String? walkerId = _request.walkerId;
      late String otherUserId;

      if (widget.isWalker) {
        // Walkers can reach out even before accepting; fall back to their own ID.
        walkerId = walkerId?.isNotEmpty == true ? walkerId : currentUserId;
        otherUserId = _request.ownerId;
      } else {
        otherUserId = walkerId ?? '';
      }

      if (otherUserId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('user_not_found')),
          ),
        );
        return;
      }

      final otherUser = await _userService.getUserById(otherUserId);
      if (otherUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('user_not_found')),
          ),
        );
        return;
      }

      final chatId = _buildChatId(walkerId);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            userId: currentUserId,
            otherUserName: otherUser.fullName,
            otherUserId: otherUser.id,
            walkRequest: _request,
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('walk_request_details')),
        backgroundColor: Colors.green[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blueGrey[50],
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _loadingDog
                    ? const Center(child: CircularProgressIndicator())
                    : _dog == null
                    ? const Text(
                        'Dog details unavailable',
                        style: TextStyle(fontSize: 16),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dog: ${_dog!.name}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_dog!.breed} • ${_dog!.age} ${t.t('years_old')}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Temperament: ${_dog!.temperament.toString().split('.').last}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Energy Level: ${_dog!.energyLevel.toString().split('.').last}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Text(
              '${t.t('location')}: ${_request.location}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start: ${DateFormat('MMM d, yyyy • h:mm a').format(_request.startTime)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'End: ${DateFormat('MMM d, yyyy • h:mm a').format(_request.endTime)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Duration: ${_request.duration} minutes',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${t.t('notes')}: ${_request.notes ?? "-"}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${t.t('status')}: ${_request.status.toString().split(".").last}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_processing) const Center(child: CircularProgressIndicator()),
            if (!_processing)
              Column(
                children: [
                  // Action buttons row
                  Row(
                    children: [
                      if (_request.status == WalkRequestStatus.pending &&
                          widget.isWalker)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _acceptRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                            ),
                            child: Text(t.t('accept')),
                          ),
                        ),
                      if ((_request.status == WalkRequestStatus.pending &&
                              !widget.isWalker) ||
                          (_request.status == WalkRequestStatus.accepted))
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _cancelRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                            ),
                            child: Text(t.t('cancel')),
                          ),
                        ),
                      if (!widget.isWalker &&
                          _request.status == WalkRequestStatus.accepted)
                        const SizedBox(width: 12),
                      if (!widget.isWalker &&
                          _request.status == WalkRequestStatus.accepted)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _rescheduleRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                            ),
                            child: Text(t.t('reschedule')),
                          ),
                        ),
                    ],
                  ),

                  // Mark complete when in accepted state (both roles)
                  if (_request.status == WalkRequestStatus.accepted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _markCompleted,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(t.t('mark_complete')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],

                  // Chat button: walkers can reach out while pending; both roles once accepted.
                  if (_request.status == WalkRequestStatus.accepted ||
                      (widget.isWalker &&
                          _request.status == WalkRequestStatus.pending)) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(
                          widget.isWalker
                              ? t.t('chat_with_owner')
                              : t.t('chat_with_walker'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],

                  // Leave a review after completion if not yet reviewed
                  if (_request.status == WalkRequestStatus.completed && !_hasLeftReview) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _promptReviewIfNeeded,
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(t.t('leave_a_review')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}
