import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';

class MessageService {
  final CollectionReference chatsCollection = FirebaseFirestore.instance.collection('chats');

  Future<void> sendMessage(MessageModel message) async {
    await chatsCollection
      .doc(message.chatId)
      .collection('messages')
      .doc(message.id)
      .set(message.toFirestore());
  }

  Stream<List<MessageModel>> getMessages(String chatId) {
    return chatsCollection
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }
} 