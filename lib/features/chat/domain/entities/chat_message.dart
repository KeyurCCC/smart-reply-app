import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final MessageStatus status;
  final DateTime createdAt;
  final String? fileName;
  final int? fileSize;
  final String? replyToMessageId;
  final String? replyToText;
  final bool? isForwarded;
  final Map<String, String>? reactions;
  final List<ChatEntity>? entities;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.type,
    required this.status,
    required this.createdAt,
    this.fileName,
    this.fileSize,
    this.replyToMessageId,
    this.replyToText,
    this.isForwarded,
    this.reactions,
    this.entities,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? text,
    MessageType? type,
    MessageStatus? status,
    DateTime? createdAt,
    String? fileName,
    int? fileSize,
    String? replyToMessageId,
    String? replyToText,
    bool? isForwarded,
    Map<String, String>? reactions,
    List<ChatEntity>? entities,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      isForwarded: isForwarded ?? this.isForwarded,
      reactions: reactions ?? this.reactions,
      entities: entities ?? this.entities,
    );
  }
}
