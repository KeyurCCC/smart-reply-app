import 'package:smart_reply_app/core/enums/smart_reply_mode.dart';
import 'package:smart_reply_app/features/chat/data/services/llm_smart_reply_service.dart';
import 'package:smart_reply_app/features/chat/data/services/smart_reply_service.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/smart_reply_result.dart';
import 'package:smart_reply_app/features/chat/domain/services/smart_reply_provider.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

class SmartReplyCoordinator implements SmartReplyProvider {
  final MlKitSmartReplyService mlKitService;
  final LlmSmartReplyService llmService;
  final SettingsRepository settingsRepository;

  SmartReplyCoordinator({
    required this.mlKitService,
    required this.llmService,
    required this.settingsRepository,
  });

  @override
  Future<SmartReplyResult> generateReplies({
    required List<ChatMessage> messages,
    required String currentUserId,
  }) async {
    final mode = await settingsRepository.getSmartReplyMode();

    switch (mode) {
      case SmartReplyMode.mlKit:
        return mlKitService.generateReplies(
          messages: messages,
          currentUserId: currentUserId,
        );
      case SmartReplyMode.gemini:
        return llmService.generateReplies(
          messages: messages,
          currentUserId: currentUserId,
        );
    }
  }
}
