import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';

abstract class ConversationsState {}

class ConversationsInitial extends ConversationsState {}

class ConversationsLoading extends ConversationsState {}

class ConversationsLoaded extends ConversationsState {
  final List<Conversation> conversations;

  ConversationsLoaded(this.conversations);
}

class ConversationStarted extends ConversationsState {
  final String conversationId;
  final String partnerName;

  ConversationStarted(this.conversationId, this.partnerName);
}

class ConversationsActionFailure extends ConversationsState {
  final String message;

  ConversationsActionFailure(this.message);
}

class ConversationsError extends ConversationsState {
  final String message;

  ConversationsError(this.message);
}
