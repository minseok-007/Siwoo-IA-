import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/message_service.dart';
import '../services/walk_request_service.dart';
import '../services/user_service.dart';
import '../services/dog_service.dart';
import '../services/auth_provider.dart';
import '../models/walk_request_model.dart';
import '../models/user_model.dart';
import '../models/dog_model.dart';
import '../models/message_model.dart';
import 'chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';

/// Screen listing chats the user participates in.
/// - Combines walk requests and chat collections, sorted by most recent message.
class ChatListScreen extends StatefulWidget {
  final String userId;
  const ChatListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final WalkRequestService _walkService = WalkRequestService();
  final UserService _userService = UserService();
  final MessageService _messageService = MessageService();
  final DogService _dogService = DogService();

  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  Map<String, int> _unreadCounts = {}; // Map of chatId -> unread message count
  Map<String, DateTime> _lastReadTimes = {}; // Map of chatId -> last read time
  Map<String, StreamSubscription> _messageSubscriptions = {}; // Real-time message listeners

  @override
  void initState() {
    super.initState();
    _loadLastReadTimes().then((_) {
      _fetchChats();
    });
  }

  @override
  void dispose() {
    // Cancel all message subscriptions
    for (var subscription in _messageSubscriptions.values) {
      subscription.cancel();
    }
    _messageSubscriptions.clear();
    super.dispose();
  }

  Future<void> _loadLastReadTimes() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('read_messages')
          .doc('read_times')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final times = (data?['times'] as Map<String, dynamic>?) ?? {};
        final readTimes = <String, DateTime>{};
        times.forEach((chatId, timestamp) {
          if (timestamp is Timestamp) {
            readTimes[chatId] = timestamp.toDate();
          }
        });
        setState(() {
          _lastReadTimes = readTimes;
        });
      }
    } catch (e) {
      print('Error loading last read times: $e');
    }
  }

  Future<int> _getUnreadCount(String chatId) async {
    try {
      final lastReadTime = _lastReadTimes[chatId];
      final currentUserId = widget.userId;
      
      // Get last message only (much faster)
      final lastMessage = await _messageService.getLastMessage(chatId);
      if (lastMessage == null) return 0;
      
      // If last message is from current user, no unread messages
      if (lastMessage.senderId == currentUserId) return 0;
      
      // If we have a last read time, check if last message is after it
      if (lastReadTime != null) {
        if (!lastMessage.timestamp.isAfter(lastReadTime)) {
          return 0; // All messages read
        }
      }
      
      // Count unread messages by getting recent messages and filtering in memory
      // This avoids index requirements
      try {
        final recentMessages = await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(50) // Limit to recent 50 messages for performance
            .get();
        
        int unreadCount = 0;
        for (var doc in recentMessages.docs) {
          final messageData = doc.data();
          final senderId = messageData['senderId'] as String?;
          final timestamp = messageData['timestamp'] as Timestamp?;
          
          // Skip messages from current user
          if (senderId == currentUserId) continue;
          
          // If we have a last read time, only count messages after it
          if (lastReadTime != null && timestamp != null) {
            if (timestamp.toDate().isAfter(lastReadTime)) {
              unreadCount++;
            } else {
              // Messages are ordered by timestamp desc, so we can break early
              break;
            }
          } else {
            // No read time, count all messages from others
            unreadCount++;
          }
        }
        
        return unreadCount;
      } catch (e) {
        // If query fails, estimate based on last message
        if (lastReadTime == null || lastMessage.timestamp.isAfter(lastReadTime)) {
          return 1; // At least 1 unread message
        }
        return 0;
      }
    } catch (e) {
      print('Error getting unread count for $chatId: $e');
      return 0;
    }
  }

  void _setupMessageListener(String chatId) {
    // Cancel existing subscription if any
    _messageSubscriptions[chatId]?.cancel();
    
    // Listen to new messages in real-time
    final subscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (!mounted) return;
      
      // Check if there's a new message
      if (snapshot.docs.isNotEmpty) {
        final lastMessageDoc = snapshot.docs.first;
        final lastMessageData = lastMessageDoc.data();
        final senderId = lastMessageData['senderId'] as String?;
        final timestamp = lastMessageData['timestamp'] as Timestamp?;
        
        // Only update if message is from someone else
        if (senderId != widget.userId && timestamp != null) {
          final lastReadTime = _lastReadTimes[chatId];
          
          // Check if this is a new unread message
          if (lastReadTime == null || timestamp.toDate().isAfter(lastReadTime)) {
            // Update unread count
            final unreadCount = await _getUnreadCount(chatId);
            
            if (mounted) {
              setState(() {
                _unreadCounts[chatId] = unreadCount;
                // Update chat item's unread count
                final index = _chats.indexWhere((chat) => chat['chatId'] == chatId);
                if (index != -1) {
                  _chats[index]['unreadCount'] = unreadCount;
                  // Update last message in chat object
                  _chats[index]['lastMessage'] = MessageModel.fromFirestore(lastMessageDoc);
                }
              });
            }
          }
        }
      }
    });
    
    _messageSubscriptions[chatId] = subscription;
  }

  Future<void> _fetchChats() async {
    setState(() => _loading = true);

    try {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user == null) return;

      // Get all walk requests where the user is involved (including pending)
      List<WalkRequestModel> walkRequests = [];

      if (user.userType == UserType.dogWalker) {
        // For walkers, get all their walks (pending, accepted, completed)
        walkRequests = await _walkService.getRequestsByWalker(user.id);
      } else {
        // For owners, get all their walk requests
        walkRequests = await _walkService.getRequestsByOwner(user.id);
      }

      // Get chat information for each walk request
      List<Map<String, dynamic>> chats = [];

      for (final walk in walkRequests) {
        try {
          // Determine the other user (owner or walker)
          String otherUserId;
          if (user.userType == UserType.dogWalker) {
            otherUserId = walk.ownerId;
          } else {
            otherUserId = walk.walkerId ?? '';
          }

          // Skip if no walker assigned yet
          if (otherUserId.isEmpty) continue;

          // Get the other user's information
          final otherUser = await _userService.getUserById(otherUserId);
          if (otherUser == null) continue;

          // Get the dog information
          final dog = await _dogService.getDogById(walk.dogId);

          // Create chat ID
          final chatId =
              'walk_${walk.id}_${walk.ownerId}_${walk.walkerId ?? ''}';

          // Get last message for preview
          final lastMessage = await _getLastMessage(chatId);

          // Only add chats that have messages or are active
          if (lastMessage != null ||
              walk.status == WalkRequestStatus.accepted ||
              walk.status == WalkRequestStatus.completed) {
            chats.add({
              'chatId': chatId,
              'walkRequest': walk,
              'otherUser': otherUser,
              'dog': dog,
              'lastMessage': lastMessage,
            });
          }
        } catch (e) {
          // Skip this chat if there's an error
          continue;
        }
      }

      // Also check for any existing chats in the messages collection
      await _addExistingChats(user, chats);

      print('Found ${chats.length} chats total');
      for (final chat in chats) {
        print('Chat: ${chat['chatId']} - ${chat['otherUser'].fullName}');
      }

      // Sort chats by last message time (most recent first)
      chats.sort((a, b) {
        final aTime = a['lastMessage']?.timestamp ?? a['walkRequest'].startTime;
        final bTime = b['lastMessage']?.timestamp ?? b['walkRequest'].startTime;
        return bTime.compareTo(aTime);
      });

      setState(() {
        _chats = chats;
        _loading = false;
      });

      // Setup real-time listeners for all chats
      for (var chat in chats) {
        final chatId = chat['chatId'] as String;
        _setupMessageListener(chatId);
      }

      // Calculate initial unread counts quickly (using last message only)
      await _calculateUnreadCountsQuick(chats);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context).t('err_loading_chats')}: $e',
          ),
        ),
      );
    }
  }

  Future<void> _addExistingChats(
    UserModel user,
    List<Map<String, dynamic>> chats,
  ) async {
    try {
      print('Searching for existing chats...');

      // Get all chat documents that exist
      final chatDocs = await FirebaseFirestore.instance
          .collection('chats')
          .get();

      print('Found ${chatDocs.docs.length} chat documents');

      // For each chat document, check if it has messages
      for (final chatDoc in chatDocs.docs) {
        final chatId = chatDoc.id;
        print('Checking chat: $chatId');

        // Check if we already have this chat in our list
        final existingChat = chats.any((chat) => chat['chatId'] == chatId);
        if (existingChat) {
          print('Chat $chatId already in list, skipping');
          continue;
        }

        try {
          // Check if this chat has any messages
          final messagesQuery = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          print('Chat $chatId has ${messagesQuery.docs.length} messages');

          if (messagesQuery.docs.isNotEmpty) {
            // This chat has messages, let's get the details
            final lastMessage = MessageModel.fromFirestore(
              messagesQuery.docs.first,
            );
            print(
              'Last message in $chatId: ${lastMessage.text} from ${lastMessage.senderId}',
            );

            // Check if the user participated in this chat
            if (lastMessage.senderId == user.id ||
                lastMessage.chatId.contains(user.id)) {
              print('User ${user.id} participated in chat $chatId');

              // Try to parse the chat ID to get walk information
              final parts = chatId.split('_');
              if (parts.length >= 4 && parts[0] == 'walk') {
                try {
                  final walkId = parts[1];
                  final ownerId = parts[2];
                  final walkerIdFromChat =
                      parts[3] != 'null' ? parts[3] : '';

                  print(
                    'Parsed walk info: walkId=$walkId, ownerId=$ownerId, walkerId=$walkerIdFromChat',
                  );

                  // Get the walk request
                  final walkDoc = await FirebaseFirestore.instance
                      .collection('walk_requests')
                      .doc(walkId)
                      .get();

                  if (walkDoc.exists) {
                    final walk = WalkRequestModel.fromFirestore(walkDoc);
                    print('Found walk request: ${walk.location}');

                    // Determine the other user
                    String otherUserId;
                    if (user.id == walk.ownerId) {
                      otherUserId =
                          walk.walkerId?.isNotEmpty == true
                              ? walk.walkerId!
                              : walkerIdFromChat;
                    } else {
                      otherUserId = walk.ownerId;
                    }

                    print('Other user ID: $otherUserId');

                    if (otherUserId.isNotEmpty) {
                      final otherUser = await _userService.getUserById(
                        otherUserId,
                      );
                      if (otherUser != null) {
                        final enrichedWalk =
                            (walk.walkerId == null || walk.walkerId!.isEmpty) &&
                                    walkerIdFromChat.isNotEmpty
                                ? walk.copyWith(walkerId: walkerIdFromChat)
                                : walk;
                        // Only try to get dog if dogId is not empty
                        DogModel? dog;
                        if (walk.dogId.isNotEmpty) {
                          try {
                            dog = await _dogService.getDogById(walk.dogId);
                          } catch (e) {
                            print('Error fetching dog ${walk.dogId}: $e');
                            dog = null;
                          }
                        }

                        chats.add({
                          'chatId': chatId,
                          'walkRequest': enrichedWalk,
                          'otherUser': otherUser,
                          'dog': dog,
                          'lastMessage': lastMessage,
                        });

                        print('Added chat $chatId with ${otherUser.fullName}');
                      }
                    }
                  }
                } catch (e) {
                  print('Error parsing chat $chatId: $e');
                  // Skip this chat if there's an error parsing
                  continue;
                }
              }
            } else {
              print('User ${user.id} did not participate in chat $chatId');
            }
          }
        } catch (e) {
          print('Error checking chat $chatId: $e');
          // Skip this chat if there's an error
          continue;
        }
      }
    } catch (e) {
      // Ignore errors when fetching existing chats
      print('Error fetching existing chats: $e');
    }
  }

  Future<MessageModel?> _getLastMessage(String chatId) async {
    try {
      return await _messageService.getLastMessage(chatId);
    } catch (e) {
      return null;
    }
  }

  void _openChat(Map<String, dynamic> chat) async {
    final walkRequest = chat['walkRequest'] as WalkRequestModel;
    final otherUser = chat['otherUser'] as UserModel;
    final chatId = chat['chatId'] as String;

    // Mark messages as read when opening chat
    await _markChatAsRead(chatId);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            userId: widget.userId,
            otherUserName: otherUser.fullName,
            otherUserId: otherUser.id,
            walkRequest: walkRequest,
          ),
        ),
      );
    
    // Refresh chat list when returning
    if (result == true || mounted) {
      _fetchChats();
    }
  }

  Future<void> _calculateUnreadCountsQuick(List<Map<String, dynamic>> chats) async {
    // Quick calculation using last message only (much faster)
    for (var chat in chats) {
      final chatId = chat['chatId'] as String;
      final lastMessage = chat['lastMessage'] as MessageModel?;
      
      if (lastMessage == null) {
        chat['unreadCount'] = 0;
        _unreadCounts[chatId] = 0;
        continue;
      }
      
      final lastReadTime = _lastReadTimes[chatId];
      final currentUserId = widget.userId;
      
      // Quick check: if last message is from current user, no unread
      if (lastMessage.senderId == currentUserId) {
        chat['unreadCount'] = 0;
        _unreadCounts[chatId] = 0;
        continue;
      }
      
      // If last message is after last read time, mark as unread (will get exact count from listener)
      if (lastReadTime == null || lastMessage.timestamp.isAfter(lastReadTime)) {
        // Set initial count to 1, real-time listener will update with exact count
        chat['unreadCount'] = 1;
        _unreadCounts[chatId] = 1;
      } else {
        chat['unreadCount'] = 0;
        _unreadCounts[chatId] = 0;
      }
    }
    
    if (mounted) {
      setState(() {});
    }
    
    // Get exact counts in background (but don't block UI)
    _calculateUnreadCountsAsync(chats);
  }

  Future<void> _calculateUnreadCountsAsync(List<Map<String, dynamic>> chats) async {
    // Calculate exact unread counts in background without blocking UI
    for (var chat in chats) {
      final chatId = chat['chatId'] as String;
      final unreadCount = await _getUnreadCount(chatId);
      
      if (mounted) {
        setState(() {
          _unreadCounts[chatId] = unreadCount;
          final index = _chats.indexWhere((c) => c['chatId'] == chatId);
          if (index != -1) {
            _chats[index]['unreadCount'] = unreadCount;
          }
        });
      }
    }
  }

  Future<void> _markChatAsRead(String chatId) async {
    try {
      final now = DateTime.now();
      
      // Get last message to set read time
      final lastMessage = await _messageService.getLastMessage(chatId);
      final readTime = lastMessage != null && lastMessage.timestamp.isAfter(now) 
          ? lastMessage.timestamp 
          : now;
      
      setState(() {
        _lastReadTimes[chatId] = readTime;
        _unreadCounts[chatId] = 0;
        // Update chat item's unread count
        final index = _chats.indexWhere((chat) => chat['chatId'] == chatId);
        if (index != -1) {
          _chats[index]['unreadCount'] = 0;
        }
      });
      
      // Save to Firestore
      final timesMap = <String, Timestamp>{};
      _lastReadTimes.forEach((id, dateTime) {
        timesMap[id] = Timestamp.fromDate(dateTime);
      });
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('read_messages')
          .doc('read_times')
          .set({
        'times': timesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking chat as read: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return AppLocalizations.of(context).t('yesterday');
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('chats')),
        backgroundColor: Colors.indigo[600],
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchChats),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.t('no_chats_yet'),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.t('chats_hint'),
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final walkRequest = chat['walkRequest'] as WalkRequestModel;
                final otherUser = chat['otherUser'] as UserModel;
                final lastMessage = chat['lastMessage'] as MessageModel?;
                final chatId = chat['chatId'] as String;
                // Get unread count from map first, then fallback to chat object
                final unreadCount = _unreadCounts[chatId] ?? chat['unreadCount'] as int? ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.indigo[100],
                          child: Icon(Icons.person, color: Colors.indigo[600]),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUser.fullName,
                            style: TextStyle(
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                              fontSize: 16,
                              color: unreadCount > 0 ? Colors.black : Colors.grey[700],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(walkRequest.status!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            walkRequest.status
                                .toString()
                                .split('.')
                                .last
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${t.t('walk_at')} ${walkRequest.location}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (chat['dog'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${t.t('dog')}: ${(chat['dog'] as DogModel).name}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (lastMessage != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  lastMessage.text,
                                  style: TextStyle(
                                    color: unreadCount > 0 ? Colors.black87 : Colors.grey[700],
                                    fontSize: 13,
                                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(lastMessage.timestamp),
                                style: TextStyle(
                                  color: unreadCount > 0 ? Colors.blue[700] : Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _openChat(chat),
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(WalkRequestStatus status) {
    switch (status) {
      case WalkRequestStatus.accepted:
        return Colors.green;
      case WalkRequestStatus.completed:
        return Colors.blue;
      case WalkRequestStatus.pending:
        return Colors.orange;
      case WalkRequestStatus.cancelled:
        return Colors.red;
    }
  }
}
