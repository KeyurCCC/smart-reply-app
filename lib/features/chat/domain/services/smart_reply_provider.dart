import 'package:smart_reply_app/features/chat/domain/entities/smart_reply_result.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';

abstract class SmartReplyProvider {
  Future<SmartReplyResult> generateReplies({
    required List<ChatMessage> messages,
    required String currentUserId,
  });
}
