import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime updatedAt;
  final bool typing;
  final Map<String, int> unreadCountMap;
  final String partnerId;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.updatedAt,
    required this.typing,
    this.unreadCountMap = const {},
    this.partnerId = '',
    this.unreadCount = 0,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> json) {
    final unreadRaw = json['unreadCount'];
    final unreadMap = <String, int>{};
    if (unreadRaw is Map) {
      unreadRaw.forEach((key, value) {
        unreadMap[key.toString()] = (value as num?)?.toInt() ?? 0;
      });
    }

    return ConversationModel(
      id: json['id'] as String? ?? '',
      participantIds:
          (json['participants'] as List<dynamic>?)?.cast<String>() ?? [],
      lastMessage: json['lastMessage'] as String? ?? '',
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      typing: json['typing'] as bool? ?? false,
      unreadCountMap: unreadMap,
    );
  }
}
