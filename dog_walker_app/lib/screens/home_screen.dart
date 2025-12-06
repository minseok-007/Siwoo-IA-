import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_provider.dart';
import '../models/user_model.dart';
import '../models/walk_request_model.dart';
import '../services/walk_request_service.dart';
import '../services/user_service.dart';
import 'walk_request_form_screen.dart';
import 'dog_list_screen.dart';
import 'walk_request_list_screen.dart';
import 'chat_list_screen.dart';
import 'scheduled_walks_screen.dart';
import 'optimal_schedule_screen.dart';
import 'recommendations_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'walk_request_detail_screen.dart';
import 'walk_application_list_screen.dart';
import 'notifications_screen.dart';
import '../widgets/badge_widget.dart';
import '../l10n/app_localizations.dart';

/// Home dashboard shown after login.
/// - Presents tailored quick actions based on the user's role.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WalkRequestService _walkRequestService = WalkRequestService();
  final UserService _userService = UserService();
  StreamSubscription<QuerySnapshot>? _walkRequestSubscription;
  StreamSubscription<QuerySnapshot>? _applicationSubscription;
  StreamSubscription<QuerySnapshot>? _ownerApplicationSubscription; // For owners to see new applications
  String? _lastNotifiedRequestId;
  String? _lastNotifiedApplicationId;
  String? _lastNotifiedOwnerApplicationId;
  bool _hasShownInitialNotification = false;
  bool _hasShownInitialApplicationNotification = false;
  bool _hasShownInitialOwnerApplicationNotification = false;
  int _notificationCount = 0;
  Set<String> _readNotificationIds = {}; // Track read notifications

  @override
  void initState() {
    super.initState();
    _setupWalkRequestListener();
    _loadNotificationCount();
    _loadReadNotifications();
  }

  Future<void> _loadReadNotifications() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    if (currentUserId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('read_notifications')
          .doc('read_ids')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final readIds = (data?['ids'] as List<dynamic>?)?.map((e) => e.toString()).toSet() ?? <String>{};
        setState(() {
          _readNotificationIds = readIds;
        });
      }
    } catch (e) {
      print('Error loading read notifications: $e');
    }
  }

  Future<void> _markNotificationsAsRead(List<String> notificationIds) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    if (currentUserId == null) return;

    try {
      // Add to read set
      setState(() {
        _readNotificationIds.addAll(notificationIds);
      });

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('read_notifications')
          .doc('read_ids')
          .set({
        'ids': _readNotificationIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update count
      _updateNotificationCount();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  Future<void> _markAllCurrentNotificationsAsRead() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    final user = auth.userModel;
    
    if (currentUserId == null || user == null) return;

    try {
      List<String> notificationIds = [];

      if (user.userType == UserType.dogOwner) {
        // Get all accepted walk requests with walker
        final acceptedQuery = await FirebaseFirestore.instance
            .collection('walk_requests')
            .where('ownerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();
        
        for (var doc in acceptedQuery.docs) {
          final data = doc.data();
          if (data['walkerId'] != null && data['walkerId'].toString().isNotEmpty) {
            notificationIds.add(doc.id);
          }
        }

        // Get all pending applications
        final applicationQuery = await FirebaseFirestore.instance
            .collection('walk_applications')
            .where('ownerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();
        
        for (var doc in applicationQuery.docs) {
          notificationIds.add(doc.id);
        }
      } else {
        // Get all accepted applications
        final query = await FirebaseFirestore.instance
            .collection('walk_applications')
            .where('walkerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();
        
        for (var doc in query.docs) {
          notificationIds.add(doc.id);
        }
      }

      if (notificationIds.isNotEmpty) {
        await _markNotificationsAsRead(notificationIds);
      }
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  Future<void> _loadNotificationCount() async {
    await _updateNotificationCount();
  }

  Future<void> _updateNotificationCount() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    final user = auth.userModel;
    
    if (currentUserId == null || user == null) return;

    try {
      int count = 0;
      
      if (user.userType == UserType.dogOwner) {
        // Count accepted walk requests with walker selected (unread only)
        final acceptedQuery = await FirebaseFirestore.instance
            .collection('walk_requests')
            .where('ownerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();
        
        final acceptedCount = acceptedQuery.docs.where((doc) {
          final data = doc.data();
          final hasWalker = data['walkerId'] != null && data['walkerId'].toString().isNotEmpty;
          final isRead = _readNotificationIds.contains(doc.id);
          return hasWalker && !isRead;
        }).length;

        // Count pending applications for owner's walk requests (unread only)
        final applicationQuery = await FirebaseFirestore.instance
            .collection('walk_applications')
            .where('ownerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();
        
        final applicationCount = applicationQuery.docs.where((doc) {
          return !_readNotificationIds.contains(doc.id);
        }).length;
        
        count = acceptedCount + applicationCount;
      } else {
        // Count accepted applications (unread only)
        final query = await FirebaseFirestore.instance
            .collection('walk_applications')
            .where('walkerId', isEqualTo: currentUserId)
            .where('status', isEqualTo: 'accepted')
            .get();
        
        count = query.docs.where((doc) {
          return !_readNotificationIds.contains(doc.id);
        }).length;
      }

      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      print('Error updating notification count: $e');
    }
  }

  @override
  void dispose() {
    _walkRequestSubscription?.cancel();
    _applicationSubscription?.cancel();
    _ownerApplicationSubscription?.cancel();
    super.dispose();
  }

  void _setupWalkRequestListener() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUserId;
    final user = auth.userModel;
    
    if (currentUserId == null || user == null) return;

    if (user.userType == UserType.dogOwner) {
      // For owners: listen to their own walk requests (all statuses to detect changes)
      final query = FirebaseFirestore.instance
          .collection('walk_requests')
          .where('ownerId', isEqualTo: currentUserId);

      _walkRequestSubscription = query.snapshots().listen((snapshot) {
        if (!mounted) return;
        
        // Update notification count
        _updateNotificationCount();
        
        // Skip initial load notifications
        if (!_hasShownInitialNotification) {
          _hasShownInitialNotification = true;
          return;
        }
        
        for (var docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.modified) {
            final request = WalkRequestModel.fromFirestore(docChange.doc);
            
            // Owner: notify when walkerId is set and status is accepted
            if (request.status == WalkRequestStatus.accepted && 
                request.walkerId != null &&
                request.walkerId!.isNotEmpty &&
                _lastNotifiedRequestId != request.id) {
              _lastNotifiedRequestId = request.id;
              _showNotification(request, user);
            }
          }
        }
      });

      // Also listen to applications for owners' walk requests
      final ownerApplicationQuery = FirebaseFirestore.instance
          .collection('walk_applications')
          .where('ownerId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending');

      _ownerApplicationSubscription = ownerApplicationQuery.snapshots().listen((snapshot) async {
        if (!mounted) return;
        
        // Update notification count
        _updateNotificationCount();
        
        // Skip initial load notifications
        if (!_hasShownInitialOwnerApplicationNotification) {
          _hasShownInitialOwnerApplicationNotification = true;
          return;
        }
        
        for (var docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.added) {
            final appData = docChange.doc.data() as Map<String, dynamic>;
            final applicationId = docChange.doc.id;
            final walkRequestId = appData['walkRequestId'] as String?;
            
            // Owner: notify when new application is received
            if (walkRequestId != null && 
                _lastNotifiedOwnerApplicationId != applicationId) {
              try {
                final request = await _walkRequestService.getRequestById(walkRequestId);
                if (request != null && mounted) {
                  _lastNotifiedOwnerApplicationId = applicationId;
                  _showApplicationNotification(request, user);
                }
              } catch (e) {
                print('Error fetching walk request for application notification: $e');
              }
            }
          }
        }
      });
    } else {
      // For walkers: listen to their applications to detect when status changes to accepted
      final applicationQuery = FirebaseFirestore.instance
          .collection('walk_applications')
          .where('walkerId', isEqualTo: currentUserId);

      _applicationSubscription = applicationQuery.snapshots().listen((snapshot) async {
        if (!mounted) return;
        
        // Update notification count
        _updateNotificationCount();
        
        // Skip initial load notifications
        if (!_hasShownInitialApplicationNotification) {
          _hasShownInitialApplicationNotification = true;
          return;
        }
        
        for (var docChange in snapshot.docChanges) {
          if (docChange.type == DocumentChangeType.modified) {
            final appData = docChange.doc.data() as Map<String, dynamic>;
            final applicationId = docChange.doc.id;
            final status = appData['status'] as String?;
            final walkRequestId = appData['walkRequestId'] as String?;
            
            // Check if status changed to accepted
            if (status == 'accepted' && 
                walkRequestId != null && 
                _lastNotifiedApplicationId != applicationId) {
              // Fetch the walk request to show in notification
              try {
                final request = await _walkRequestService.getRequestById(walkRequestId);
                if (request != null && mounted) {
                  _lastNotifiedApplicationId = applicationId;
                  _showNotification(request, user);
                }
              } catch (e) {
                print('Error fetching walk request for notification: $e');
              }
            }
          }
        }
      });
    }
  }

  void _showNotification(WalkRequestModel request, UserModel user) {
    if (!mounted) return;
    
    String message;
    if (user.userType == UserType.dogOwner) {
      // Owner: walker was selected
      message = 'A walker has been selected for your walk request!';
    } else {
      // Walker: application was accepted
      message = 'Your application has been accepted!';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            _navigateToRequest(request, user);
          },
        ),
      ),
    );
  }

  void _showApplicationNotification(WalkRequestModel request, UserModel user) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.person_add, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'New application received for your walk request!',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[600],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            _navigateToRequest(request, user);
          },
        ),
      ),
    );
  }

  void _navigateToRequest(WalkRequestModel request, UserModel user) {
    if (!mounted) return;
    
    if (user.userType == UserType.dogOwner) {
      // Navigate to application list for owner
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WalkApplicationListScreen(walkRequest: request),
        ),
      );
    } else {
      // Navigate to walk request detail for walker
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WalkRequestDetailScreen(
            request: request,
            isWalker: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'PawPal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
        actions: [
          // Notification button with badge
          IconButton(
            icon: BadgeWidget(
              count: _notificationCount,
              child: const Icon(Icons.notifications, color: Colors.white),
            ),
            onPressed: () async {
              // Mark all current notifications as read when opening screen
              await _markAllCurrentNotificationsAsRead();
              
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
              // Refresh notification count when returning
              _loadNotificationCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.userModel == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final user = authProvider.userModel!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[600]!, Colors.blue[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Icon(
                              user.userType == UserType.dogOwner 
                                  ? Icons.pets 
                                  : Icons.directions_walk,
                              size: 30,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.t('welcome_back_comma'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  user.userType == UserType.dogOwner 
                                      ? t.t('dog_owner') 
                                      : t.t('dog_walker'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions
                Text(
                  t.t('quick_actions'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                if (user.userType == UserType.dogOwner) ...[
                  // Dog Owner Actions
                  _buildActionCard(
                    context,
                    t.t('post_walk_request'),
                    t.t('post_walk_request_desc'),
                    Icons.add_circle_outline,
                    Colors.green,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WalkRequestFormScreen(ownerId: user.id),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    t.t('my_dogs'),
                    t.t('my_dogs_desc'),
                    Icons.pets,
                    Colors.orange,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DogListScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    t.t('my_walk_requests'),
                    t.t('my_walk_requests_desc'),
                    Icons.history,
                    Colors.purple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalkRequestListScreen(isWalker: false),
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // Dog Walker Actions
                  _buildActionCard(
                    context,
                    t.t('available_walks'),
                    t.t('available_walks_desc'),
                    Icons.search,
                    Colors.green,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WalkRequestListScreen(isWalker: true),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    t.t('my_schedule'),
                    t.t('my_schedule_desc'),
                    Icons.calendar_today,
                    Colors.blue,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ScheduledWalksScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'Optimal Schedule',
                    'AI-powered schedule optimization',
                    Icons.auto_awesome,
                    Colors.purple,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OptimalScheduleScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context,
                    'AI Recommendations',
                    'Personalized recommendations using ML',
                    Icons.recommend,
                    Colors.pink,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecommendationsScreen(),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 24),

                // Common Actions
                Text(
                  t.t('more'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                _buildActionCard(
                  context,
                  t.t('messages'),
                  t.t('messages_desc'),
                  Icons.chat_bubble_outline,
                  Colors.indigo,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatListScreen(userId: user.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                _buildActionCard(
                  context,
                  t.t('profile'),
                  t.t('profile_desc'),
                  Icons.person_outline,
                  Colors.teal,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionCard(
                  context,
                  t.t('settings'),
                  t.t('app_preferences'),
                  Icons.settings,
                  Colors.grey,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
