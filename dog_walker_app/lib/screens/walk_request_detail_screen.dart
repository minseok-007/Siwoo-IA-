import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';
import '../l10n/app_localizations.dart';

/// 산책 요청 상세 화면.
/// - 워커는 수락, 오너는 취소/재조정 등 역할 기반 액션을 제공합니다.
class WalkRequestDetailScreen extends StatefulWidget {
  final WalkRequestModel request;
  final bool isWalker;
  const WalkRequestDetailScreen({Key? key, required this.request, required this.isWalker}) : super(key: key);

  @override
  State<WalkRequestDetailScreen> createState() => _WalkRequestDetailScreenState();
}

class _WalkRequestDetailScreenState extends State<WalkRequestDetailScreen> {
  bool _processing = false;
  late WalkRequestModel _request;
  final WalkRequestService _service = WalkRequestService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  Future<void> _acceptRequest() async {
    setState(() => _processing = true);
    
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).t('user_not_authenticated'))),
      );
      return;
    }

    try {
      final updated = _request.copyWith(
        status: WalkRequestStatus.accepted,
        walkerId: user.uid,
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
        SnackBar(content: Text('${AppLocalizations.of(context).t('err_accept_request')}: $e')),
      );
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => _processing = true);
    try {
      final updated = _request.copyWith(status: WalkRequestStatus.cancelled);
      await _service.updateWalkRequest(updated);
      setState(() {
        _request = updated;
        _processing = false;
      });
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).t('err_cancel_request')}: $e')),
      );
    }
  }

  Future<void> _rescheduleRequest() async {
    // TODO: Implement rescheduling logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).t('reschedule_not_implemented'))),
    );
  }

  Future<void> _startChat() async {
    try {
      String otherUserId;
      if (widget.isWalker) {
        otherUserId = _request.ownerId;
      } else {
        otherUserId = _request.walkerId!;
      }

      final otherUser = await _userService.getUserById(otherUserId);
      if (otherUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).t('user_not_found'))),
        );
        return;
      }

      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user == null) return;

      // Create a unique chat ID based on walk request and participants
      final chatId = 'walk_${_request.id}_${_request.ownerId}_${_request.walkerId}';
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            userId: user.uid,
            otherUserName: otherUser.fullName,
            walkRequest: _request,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).t('err_start_chat')}: $e')),
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
            Text('${t.t('location')}: ${_request.location}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${t.t('time')}: ${_request.time}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('${t.t('notes')}: ${_request.notes ?? "-"}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text('${t.t('status')}: ${_request.status.toString().split(".").last}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            if (_processing) const Center(child: CircularProgressIndicator()),
            if (!_processing)
              Column(
                children: [
                  // Action buttons row
                  Row(
                    children: [
                      if (widget.isWalker && _request.status == WalkRequestStatus.pending)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _acceptRequest,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                            child: Text(t.t('accept')),
                          ),
                        ),
                      if (!widget.isWalker && _request.status == WalkRequestStatus.pending)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _cancelRequest,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
                            child: Text(t.t('cancel')),
                          ),
                        ),
                      if (!widget.isWalker && _request.status == WalkRequestStatus.accepted)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _rescheduleRequest,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]),
                            child: Text(t.t('reschedule')),
                          ),
                        ),
                    ],
                  ),
                  
                  // Chat button for accepted walks
                  if (_request.status == WalkRequestStatus.accepted) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startChat,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(widget.isWalker ? t.t('chat_with_owner') : t.t('chat_with_walker')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[600],
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
