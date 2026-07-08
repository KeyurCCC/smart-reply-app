import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';

abstract class ChatEvent {}

class LoadChatEvent extends ChatEvent {
  final String conversationId;

  LoadChatEvent(this.conversationId);
}

class ReceiveMessagesEvent extends ChatEvent {
  final List<ChatMessage> messages;

  ReceiveMessagesEvent(this.messages);
}

class SendMessageEvent extends ChatEvent {
  final String conversationId;
  final String message;

  SendMessageEvent({
    required this.conversationId,
    required this.message,
  });
}

class GenerateSmartReplyEvent extends ChatEvent {
  final List<ChatMessage> messages;

  GenerateSmartReplyEvent(this.messages);
}

class ClearSmartRepliesEvent extends ChatEvent {}

class DeleteMessageEvent extends ChatEvent {
  final String conversationId;
  final String messageId;

  DeleteMessageEvent({
    required this.conversationId,
    required this.messageId,
  });
}
