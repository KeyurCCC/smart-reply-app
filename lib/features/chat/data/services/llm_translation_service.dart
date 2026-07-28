import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:smart_reply_app/features/chat/domain/services/translation_service.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

class LlmTranslationService implements TranslationService {
  static const _models = ['gemini-3.1-flash-lite-preview'];

  final SettingsRepository settingsRepository;

  LlmTranslationService({required this.settingsRepository});

  @override
  Future<String> translateText({
    required String text,
    required String targetLanguage,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    final apiKey = await settingsRepository.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return '[Translation Error: Please configure your Gemini API Key in Settings]';
    }

    final prompt = '''
Translate the following chat message into $targetLanguage.

Rules:
- Return ONLY the exact translated text.
- Do NOT add quotation marks, commentary, explanations, or notes.
- Keep emoticons, emojis, and punctuation natural to the message.

Message:
$trimmed
''';

    for (final modelName in _models) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        final translated = response.text?.trim() ?? '';
        if (translated.isNotEmpty) {
          return translated;
        }
      } catch (e) {
        debugPrint('[Translation] Error with model $modelName: $e');
      }
    }

    return '[Translation failed]';
  }
}
