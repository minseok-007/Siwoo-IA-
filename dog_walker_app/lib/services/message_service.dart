import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

/// 채팅 메시지 전송/조회 전용 서비스.
/// - 상위 레이어는 채팅 비즈니스 로직에 집중할 수 있고, 저장소 세부는 이곳에서 처리합니다.
class MessageService {
  final CollectionReference chatsCollection = FirebaseFirestore.instance.collection('chats');

  Future<void> sendMessage(MessageModel message) async {
    // Save message to the messages subcollection
    await chatsCollection
        .doc(message.chatId)
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore());
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
  Future<void> initializeChat(String chatId) async {
    try {
      final chatDoc = chatsCollection.doc(chatId);
      final chatSnapshot = await chatDoc.get();
      
      if (!chatSnapshot.exists) {
        // Create the chat document with basic info
        await chatDoc.set({
          'chatId': chatId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessageAt': FieldValue.serverTimestamp(),
        });
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
