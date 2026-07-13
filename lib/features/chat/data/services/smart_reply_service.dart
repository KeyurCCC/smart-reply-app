import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/smart_reply_result.dart';
import 'package:smart_reply_app/features/chat/domain/services/smart_reply_provider.dart';

class MlKitSmartReplyService implements SmartReplyProvider {
  @override
  Future<SmartReplyResult> generateReplies({
    required List<ChatMessage> messages,
    required String currentUserId,
  }) async {
    if (messages.isEmpty) return const SmartReplyResult();

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
      return SmartReplyResult(replies: response.suggestions);
    } catch (e) {
      return SmartReplyResult(error: e.toString());
    } finally {
      smartReply.close();
    }
  }
}
