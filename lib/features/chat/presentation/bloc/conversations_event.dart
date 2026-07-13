import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';

abstract class ConversationsEvent {}

class LoadConversationsEvent extends ConversationsEvent {}

class ConversationsUpdatedEvent extends ConversationsEvent {
  final List<Conversation> conversations;

  ConversationsUpdatedEvent(this.conversations);
}

class StartConversationByEmailEvent extends ConversationsEvent {
  final String email;

  StartConversationByEmailEvent(this.email);
}

class ConversationsFailedEvent extends ConversationsEvent {
  final String message;

  ConversationsFailedEvent(this.message);
}

class ReconnectConversationsEvent extends ConversationsEvent {}
