import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatMessage> messages;
  final List<String> smartReplies;
  final bool isGeneratingSmartReplies;
  final String? smartReplyError;
  final bool partnerTyping;

  ChatLoaded({
    required this.messages,
    this.smartReplies = const [],
    this.isGeneratingSmartReplies = false,
    this.smartReplyError,
    this.partnerTyping = false,
  });
}

class ChatSending extends ChatState {}

class ChatError extends ChatState {

  final String message;

  ChatError(this.message);

}