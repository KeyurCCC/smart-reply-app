import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';

abstract class RealtimeChatDatasource {
  Stream<List<ConversationModel>> listenConversations(String userId);

  Stream<List<ChatMessageModel>> listenMessages(String conversationId);

  Future<String> createConversation({
    required String conversationId,
    required List<String> participants,
  });

  Future<void> sendMessage({
    required String conversationId,
    required ChatMessageModel message,
  });

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  Future<void> updateConversation({
    required String conversationId,
    required String lastMessage,
    Map<String, int>? unreadCount,
    required List<String> participants,
  });

  Future<void> updateTypingStatus({
    required String conversationId,
    required String userId,
    required bool typing,
  });

  Stream<bool> listenTypingStatus({
    required String conversationId,
    required String partnerId,
  });

  Future<void> markMessageRead({
    required String conversationId,
    required String messageId,
  });

  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  });

  Future<void> resetUnreadCount({
    required String conversationId,
    required String userId,
    required List<String> participants,
  });

  Future<Map<String, dynamic>?> getConversation(String conversationId);

  Future<void> ensureConversationSetup({
    required String conversationId,
    required List<String> participants,
  });
}
