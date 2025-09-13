/* 요약: 추천 품질과 신뢰도를 높이기 위해 평점/후기를 독립 모델로 관리한다.
   WHAT/HOW: 정렬·필터에 필요한 최소 필드와 Timestamp를 표준화해 저장한다. */
import 'package:cloud_firestore/cloud_firestore.dart';

// 추천과 신뢰도 계산의 근거 데이터로 쓰기 위해 후기를 도메인 모델로 분리했다.
class ReviewModel {
  final String id;
  final String reviewerId;
  final String revieweeId;
  final String walkId;
  final double rating;
  final String comment;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    required this.walkId,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  // 외부 저장 데이터를 앱 모델로 안전하게 복원하려고 타입 변환을 일원화한다.
  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      reviewerId: data['reviewerId'] ?? '',
      revieweeId: data['revieweeId'] ?? '',
      walkId: data['walkId'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(), // 정밀도를 확보하려고 double로 변환한다.
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(), // 정렬과 필터의 기준으로 쓰기 위함.
    );
  }

  // 분석과 정렬에 친화적인 스키마를 유지하려고 최소 필드만 직렬화한다.
  Map<String, dynamic> toFirestore() {
    return {
      'reviewerId': reviewerId,
      'revieweeId': revieweeId,
      'walkId': walkId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp), // 서버 기준 시간을 유지하기 위함.
    };
  }
} 
