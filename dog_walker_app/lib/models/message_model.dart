/* Summary: Separate messages into their own model to keep chat logic isolated and
   ordering performant. WHAT/HOW: Persist consistently using Firestore Timestamps
   and slugs. */
import 'package:cloud_firestore/cloud_firestore.dart';

// Keep the fields lean to optimize sorting and lookups at the conversation level.
/// Chat message model.
/// - Field choices make time ordering, sender lookups, and per-chat grouping straightforward.
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  // Use server-generated timestamps to keep ordering and sync consistent.
  /// Deserialize a Firestore document into the model.
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(), // Enables ordering by server time
    );
  }

  // Persist normalized fields only to keep queries consistent and cost-effective.
  /// Serialize the model into a Firestore map.
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp), // Primary key for timeline ordering
    };
  }
} 
