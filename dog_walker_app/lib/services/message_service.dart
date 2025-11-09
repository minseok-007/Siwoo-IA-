import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

/// Service dedicated to sending and retrieving chat messages.
/// - Keeps higher layers focused on chat business logic while persistence lives here.
class MessageService {
  final CollectionReference chatsCollection = FirebaseFirestore.instance.collection('chats');

  Future<void> sendMessage(MessageModel message) async {
    final chatRef = chatsCollection.doc(message.chatId);

    // Save message to the messages subcollection
    await chatRef
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore());

    // Update chat metadata
    await chatRef.set(
      {
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    // Get messages from the messages subcollection
    return chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromFirestore(doc))
            .toList());
  }

  // Initialize chat document if it doesn't exist
  Future<void> initializeChat(
    String chatId, {
    String? ownerId,
    String? walkerId,
  }) async {
    try {
      final chatDoc = chatsCollection.doc(chatId);
      final chatSnapshot = await chatDoc.get();

      final participants = <String>{};
      if (ownerId != null && ownerId.isNotEmpty) participants.add(ownerId);
      if (walkerId != null && walkerId.isNotEmpty) participants.add(walkerId);

      final data = <String, dynamic>{
        'chatId': chatId,
      };
      if (ownerId != null && ownerId.isNotEmpty) data['ownerId'] = ownerId;
      if (walkerId != null && walkerId.isNotEmpty) data['walkerId'] = walkerId;
      if (participants.isNotEmpty) {
        final participantList = <String>[
          if (ownerId != null && ownerId.isNotEmpty) ownerId,
          if (walkerId != null && walkerId.isNotEmpty && walkerId != ownerId)
            walkerId,
        ];
        data['participants'] = participantList;
      }
      
      if (!chatSnapshot.exists) {
        // Create the chat document with basic info
        await chatDoc.set({
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
      } else if (participants.isNotEmpty) {
        final existingData = chatSnapshot.data() as Map<String, dynamic>?;
        final existingOwner = existingData != null &&
                existingData['ownerId'] is String
            ? existingData['ownerId'] as String
            : null;
        final existingWalker = existingData != null &&
                existingData['walkerId'] is String
            ? existingData['walkerId'] as String
            : null;

        final resolvedOwnerId =
            (ownerId != null && ownerId.isNotEmpty) ? ownerId : existingOwner;
        final resolvedWalkerId =
            (walkerId != null && walkerId.isNotEmpty) ? walkerId : existingWalker;

        final participantList = <String>[
          if (resolvedOwnerId != null && resolvedOwnerId.isNotEmpty)
            resolvedOwnerId,
          if (resolvedWalkerId != null && resolvedWalkerId.isNotEmpty &&
              resolvedWalkerId != resolvedOwnerId)
            resolvedWalkerId,
        ];

        await chatDoc.set(
          {
            if (ownerId != null && ownerId.isNotEmpty) 'ownerId': ownerId,
            if (walkerId != null && walkerId.isNotEmpty) 'walkerId': walkerId,
            'participants': participantList,
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      // Chat might already exist, ignore error
    }
  }

  // Get the last message for a chat (for preview in chat list)
  Future<MessageModel?> getLastMessage(String chatId) async {
    try {
      final querySnapshot = await chatsCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return MessageModel.fromFirestore(querySnapshot.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
} 
