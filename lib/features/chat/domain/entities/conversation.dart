import 'chat_user.dart';

class Conversation {
  final String id;

  final List<ChatUser> participants;

  final String lastMessage;

  final DateTime updatedAt;

  final bool typing;

  final int unreadCount;

  const Conversation({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.updatedAt,
    required this.typing,
    required this.unreadCount,
  });

  Conversation copyWith({
    String? id,
    List<ChatUser>? participants,
    String? lastMessage,
    DateTime? updatedAt,
    bool? typing,
    int? unreadCount,
  }) {
    return Conversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
      typing: typing ?? this.typing,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
