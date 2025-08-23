import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/walk_request_model.dart';
import '../models/user_model.dart';
import '../services/walk_request_service.dart';
import '../services/auth_provider.dart';
import '../services/user_service.dart';
import 'chat_screen.dart';

class ScheduledWalksScreen extends StatefulWidget {
  const ScheduledWalksScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledWalksScreen> createState() => _ScheduledWalksScreenState();
}

class _ScheduledWalksScreenState extends State<ScheduledWalksScreen> {
  final WalkRequestService _walkService = WalkRequestService();
  final UserService _userService = UserService();
  List<WalkRequestModel> _scheduledWalks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchScheduledWalks();
  }

  Future<void> _fetchScheduledWalks() async {
    setState(() => _loading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user == null) return;

    try {
      final walks = await _walkService.getRequestsByWalker(user.uid);
      setState(() {
        _scheduledWalks = walks.where((walk) => 
          walk.status == WalkRequestStatus.accepted || 
          walk.status == WalkRequestStatus.completed
        ).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading scheduled walks: $e')),
      );
    }
  }

  Future<void> _startChat(WalkRequestModel walk) async {
    try {
      final owner = await _userService.getUserById(walk.ownerId);
      if (owner == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find dog owner information')),
        );
        return;
      }

      // Create a unique chat ID based on walk request and participants
      final chatId = 'walk_${walk.id}_${walk.ownerId}_${walk.walkerId}';
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            userId: walk.walkerId!,
            otherUserName: owner.fullName,
            walkRequest: walk,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Scheduled Walks'),
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
                        'No scheduled walks yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Accept walk requests to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
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
                                        _formatDateTime(walk.time),
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
                                    walk.status.toString().split('.').last.toUpperCase(),
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
                                'Notes: ${walk.notes}',
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
                                    label: const Text('Chat with Owner'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo[600],
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (walk.status == WalkRequestStatus.accepted)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        // TODO: Implement mark as completed functionality
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Mark as completed - Coming Soon!'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text('Mark Complete'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.green[600],
                                        side: BorderSide(color: Colors.green[600]!),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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