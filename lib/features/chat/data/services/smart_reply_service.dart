import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';

class SmartReplyService {
  Future<List<String>> generateReplies({
    required List<ChatMessage> messages,
    required String currentUserId,
  }) async {
    if (messages.isEmpty) return [];

    final smartReply = SmartReply();
    try {
      final recent = messages.length > 10
          ? messages.sublist(messages.length - 10)
          : messages;

      for (final message in recent) {
        final timestamp = message.createdAt.millisecondsSinceEpoch;
        if (message.senderId == currentUserId) {
          smartReply.addMessageToConversationFromLocalUser(
            message.text,
            timestamp,
          );
        } else {
          smartReply.addMessageToConversationFromRemoteUser(
            message.text,
            timestamp,
            message.senderId,
          );
        }
      }

      final response = await smartReply.suggestReplies();
      return response.suggestions;
    } finally {
      smartReply.close();
    }
  }
}
