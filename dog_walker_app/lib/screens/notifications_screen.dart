import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/walk_request_model.dart';
import '../models/walk_application_model.dart';
import '../services/auth_provider.dart';
import '../services/walk_request_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import 'walk_request_detail_screen.dart';
import 'walk_application_list_screen.dart';

/// Screen displaying notifications for walk request confirmations.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final WalkRequestService _walkRequestService = WalkRequestService();
  final UserService _userService = UserService();
  List<NotificationItem> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    final user = auth.userModel;
    
    if (currentUserId == null || user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      List<NotificationItem> notifications = [];

      if (user.userType == UserType.dogOwner) {
        // For owners: find walk requests where walker was selected
        final acceptedQuery = await FirebaseFirestore.instance
            .collection('walk_requests')
            .where('ownerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (var doc in acceptedQuery.docs) {
          final request = WalkRequestModel.fromFirestore(doc);
          if (request.walkerId != null && request.walkerId!.isNotEmpty) {
            final walker = await _userService.getUserById(request.walkerId!);
            notifications.add(NotificationItem(
              id: request.id,
              type: NotificationType.walkerSelected,
              title: 'Walker Selected',
              message: walker != null
                  ? '${walker.fullName} has been selected for your walk request'
                  : 'A walker has been selected for your walk request',
              walkRequest: request,
              timestamp: request.updatedAt,
            ));
          }
        }

        // Also show pending applications
        final applicationQuery = await FirebaseFirestore.instance
            .collection('walk_applications')
            .where('ownerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        for (var doc in applicationQuery.docs) {
          final appData = doc.data();
          final walkRequestId = appData['walkRequestId'] as String?;
          if (walkRequestId != null) {
            final request = await _walkRequestService.getRequestById(walkRequestId);
            if (request != null) {
              final walkerId = appData['walkerId'] as String?;
              final walker = walkerId != null ? await _userService.getUserById(walkerId) : null;
              notifications.add(NotificationItem(
                id: doc.id,
                type: NotificationType.newApplication,
                title: 'New Application',
                message: walker != null
                    ? '${walker.fullName} applied for your walk request'
                    : 'A walker applied for your walk request',
                walkRequest: request,
                timestamp: (appData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              ));
            }
          }
        }
      } else {
        // For walkers: find applications that were accepted
        final query = await FirebaseFirestore.instance
            .collection('walk_applications')
            .where('walkerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();

        for (var doc in query.docs) {
          final appData = doc.data();
          final walkRequestId = appData['walkRequestId'] as String?;
          if (walkRequestId != null) {
            final request = await _walkRequestService.getRequestById(walkRequestId);
            if (request != null) {
              final owner = await _userService.getUserById(request.ownerId);
              notifications.add(NotificationItem(
                id: doc.id,
                type: NotificationType.applicationAccepted,
                title: 'Application Accepted',
                message: owner != null
                    ? '${owner.fullName} accepted your application'
                    : 'Your application has been accepted',
                walkRequest: request,
                timestamp: request.updatedAt,
              ));
            }
          }
        }
      }

      // Sort by timestamp (newest first)
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  void _onNotificationTap(NotificationItem notification) {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    if (user.userType == UserType.dogOwner) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WalkApplicationListScreen(
            walkRequest: notification.walkRequest,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WalkRequestDetailScreen(
            request: notification.walkRequest,
            isWalker: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue[600],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notification.message),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d, y • h:mm a').format(notification.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _onNotificationTap(notification),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

enum NotificationType {
  walkerSelected,
  applicationAccepted,
  newApplication,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final WalkRequestModel walkRequest;
  final DateTime timestamp;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.walkRequest,
    required this.timestamp,
  });
}
