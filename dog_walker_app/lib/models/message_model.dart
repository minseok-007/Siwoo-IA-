/* 요약: 채팅의 독립성과 정렬 성능을 높이기 위해 메시지를
   전용 모델로 분리했다. WHAT/HOW: Firestore Timestamp/슬러그로 일관 저장한다. */
import 'package:cloud_firestore/cloud_firestore.dart';

// 대화 단위 정렬과 조회를 최적화하려고 최소 필드로 설계했다.
/// 채팅 메시지 모델.
/// - 시간 정렬, 작성자 구분, 채팅방 기준으로 메시지 그룹화가 용이하도록 필드를 설계했습니다.
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

  // 서버 생성 시간 기준으로 정렬과 동기화를 보장하려고 Timestamp를 활용한다.
  /// Firestore 문서를 모델로 역직렬화.
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(), // 서버 시각 기준으로 정렬하기 위함.
    );
  }

  // 쿼리 일관성과 비용 절감을 위해 정규화된 필드만 저장한다.
  /// 모델을 Firestore Map으로 직렬화.
  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp), // 타임라인 정렬의 기준 키로 사용하기 위함.
    };
  }
} 
