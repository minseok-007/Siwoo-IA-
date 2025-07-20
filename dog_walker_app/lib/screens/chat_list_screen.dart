import 'package:flutter/material.dart';
import '../services/message_service.dart';
import '../models/message_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  final String userId;
  const ChatListScreen({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // For demo, show a static list of chatIds. In production, fetch from Firestore.
    final chatIds = <String>["chat1", "chat2", "chat3"];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.indigo[600],
      ),
      body: ListView.builder(
        itemCount: chatIds.length,
        itemBuilder: (context, index) {
          final chatId = chatIds[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.indigo),
              title: Text('Chat with $chatId'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(chatId: chatId, userId: userId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
} 