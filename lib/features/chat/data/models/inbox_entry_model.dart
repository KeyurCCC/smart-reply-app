import 'conversation_model.dart';

class InboxEntryModel {
  final String conversationId;
  final String partnerId;
  final String lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  const InboxEntryModel({
    required this.conversationId,
    required this.partnerId,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
  });

  factory InboxEntryModel.fromMap(String id, Map<String, dynamic> json) {
    final updatedVal = json['updatedAt'];
    DateTime updatedAt;
    if (updatedVal is int) {
      updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedVal);
    } else {
      updatedAt = DateTime.now();
    }

    return InboxEntryModel(
      conversationId: json['conversationId'] as String? ?? id,
      partnerId: json['partnerId'] as String? ?? '',
      lastMessage: json['lastMessage'] as String? ?? '',
      updatedAt: updatedAt,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  ConversationModel toConversationModel() {
    return ConversationModel(
      id: conversationId,
      participantIds: [partnerId],
      lastMessage: lastMessage,
      updatedAt: updatedAt,
      typing: false,
      unreadCountMap: {partnerId: unreadCount},
      partnerId: partnerId,
      unreadCount: unreadCount,
    );
  }
}
