import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

abstract class ChatAnalyzerService {
  Future<List<ChatEntity>> analyzeMessage({
    required ChatMessage targetMessage,
    required List<ChatMessage> history,
    required String currentUserId,
  });
}
