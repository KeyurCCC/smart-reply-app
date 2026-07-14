import 'package:smart_reply_app/core/result/result.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/smart_reply_result.dart';
import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';

abstract class ChatRepository {
  String? get currentUserId;

  Stream<List<Conversation>> listenConversations();

  Stream<List<ChatMessage>> listenMessages(String conversationId);

  Future<Result<String>> createConversation(List<String> participants);

  Future<void> sendMessage({
    required String conversationId,
    required String message,
  });

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<SmartReplyResult> generateSmartReplies(List<ChatMessage> messages);

  Future<void> markConversationRead(String conversationId);

  Future<void> updateTypingStatus({
    required String conversationId,
    required bool typing,
  });

  Stream<bool> listenTypingStatus({
    required String conversationId,
    required String partnerId,
  });

  Future<void> markMessagesAsRead(String conversationId, List<String> messageIds);

  Future<void> ensureAuthReady();

  Future<void> ensureConversationReady(String conversationId);
}
