import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  const ChatMessageModel({
    required super.id,
    required super.senderId,
    required super.text,
    required super.type,
    required super.status,
    required super.createdAt,
    super.fileName,
    super.fileSize,
    super.replyToMessageId,
    super.replyToText,
    super.isForwarded,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> json) {
    final createdVal = json['createdAt'];
    DateTime createdAt;
    if (createdVal is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdVal);
    } else {
      createdAt = DateTime.now();
    }

    return ChatMessageModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      type: MessageType.values.firstWhere((e) => e.name == json['type']),
      status: MessageStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: createdAt,
      fileName: json['fileName'] as String?,
      fileSize: json['fileSize'] as int?,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyToText: json['replyToText'] as String?,
      isForwarded: json['isForwarded'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToText != null) 'replyToText': replyToText,
      if (isForwarded != null) 'isForwarded': isForwarded,
    };
  }
}
