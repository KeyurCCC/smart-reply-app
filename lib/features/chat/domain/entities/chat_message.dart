import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final MessageStatus status;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    MessageType? type,
    MessageStatus? status,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
