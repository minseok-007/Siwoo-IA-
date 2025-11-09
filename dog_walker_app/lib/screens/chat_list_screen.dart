import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchChats();
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

  void _openChat(Map<String, dynamic> chat) {
    final walkRequest = chat['walkRequest'] as WalkRequestModel;
    final otherUser = chat['otherUser'] as UserModel;
    final chatId = chat['chatId'] as String;

    Navigator.push(
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
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo[100],
                      child: Icon(Icons.person, color: Colors.indigo[600]),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            otherUser.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(lastMessage.timestamp),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
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
