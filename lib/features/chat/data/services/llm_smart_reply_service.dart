import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/smart_reply_result.dart';
import 'package:smart_reply_app/features/chat/domain/services/smart_reply_provider.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

class LlmSmartReplyService implements SmartReplyProvider {
  static const _models = ['gemini-3.1-flash-lite-preview'];

  final FirebaseFunctions functions;
  final SettingsRepository settingsRepository;

  LlmSmartReplyService({FirebaseFunctions? functions, required this.settingsRepository})
    : functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<SmartReplyResult> generateReplies({required List<ChatMessage> messages, required String currentUserId}) async {
    if (messages.isEmpty) return const SmartReplyResult();

    final recent = messages.length > 10 ? messages.sublist(messages.length - 10) : messages;

    final apiKey = await settingsRepository.getGeminiApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      final direct = await _generateViaDirectGemini(recent: recent, currentUserId: currentUserId, apiKey: apiKey);
      if (direct.replies.isNotEmpty) return direct;
      if (direct.error != null) {
        debugPrint('[Gemini] Direct API failed: ${direct.error}');
      }
    }

    final fromFunction = await _generateViaCloudFunction(recent: recent, currentUserId: currentUserId);
    if (fromFunction.replies.isNotEmpty) return fromFunction;

    if (apiKey == null || apiKey.isEmpty) {
      return const SmartReplyResult(error: 'Add your Gemini API key in Settings, or deploy Cloud Functions.');
    }

    return SmartReplyResult(
      replies: fromFunction.replies,
      error: fromFunction.error ?? 'Gemini returned no suggestions. Check your API key and network.',
    );
  }

  Future<SmartReplyResult> _generateViaCloudFunction({
    required List<ChatMessage> recent,
    required String currentUserId,
  }) async {
    try {
      final callable = functions.httpsCallable(
        'generateSmartReplies',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'messages': recent.map((message) => {'text': message.text, 'senderId': message.senderId}).toList(),
        'currentUserId': currentUserId,
      });

      final replies = _parseReplies(result.data['replies']);
      if (replies.isNotEmpty) {
        return SmartReplyResult(replies: replies);
      }
      return const SmartReplyResult(error: 'Cloud Function returned no suggestions.');
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[Gemini] Cloud Function error: ${e.code} ${e.message}');
      return SmartReplyResult(error: 'Cloud Function unavailable (${e.code}). Using direct API.');
    } catch (e) {
      debugPrint('[Gemini] Cloud Function error: $e');
      return SmartReplyResult(error: 'Cloud Function failed: $e');
    }
  }

  Future<SmartReplyResult> _generateViaDirectGemini({
    required List<ChatMessage> recent,
    required String currentUserId,
    required String apiKey,
  }) async {
    final prompt = _buildPrompt(recent, currentUserId);
    Object? lastError;

    for (final modelName in _models) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: apiKey);

        final response = await model.generateContent([Content.text(prompt)]);

        final replies = _parseRepliesFromText(response.text ?? '');
        if (replies.isNotEmpty) {
          debugPrint('[Gemini] Suggestions from $modelName');
          return SmartReplyResult(replies: replies);
        }
      } catch (e) {
        lastError = e;
        debugPrint('[Gemini] $modelName failed: $e');
      }
    }

    return SmartReplyResult(error: lastError?.toString() ?? 'Gemini returned an empty response.');
  }

  String _buildPrompt(List<ChatMessage> messages, String currentUserId) {
    final transcript = messages
        .map((message) {
          final role = message.senderId == currentUserId ? 'Me' : 'Them';
          return '$role: ${message.text}';
        })
        .join('\n');

    return '''
You generate Smart Reply suggestions for a messaging app.

Your job is NOT to continue the conversation as an AI assistant.
Your job is ONLY to suggest replies that the user ("Me") could realistically send next.

Rules:

- Return EXACTLY 3 replies.
- Every reply must be different in intention.
- Avoid repeating the same wording.
- Keep each reply under 80 characters.
- Sound like a real person texting.
- Match the conversation's tone.
- Never explain anything.
- Never add numbering.
- Never use markdown.

Try to make the three replies represent different styles such as:

• Friendly / warm
• Curious / asking a follow-up
• Playful / humorous (when appropriate)
• Supportive
• Short acknowledgement
• Enthusiastic
• Thoughtful
• Agreeing
• Suggesting something
• Politely declining
• Flirty (ONLY if the conversation already has that tone)

If appropriate, make one reply very short (1–3 words), one medium, and one more conversational.

Avoid generic replies like:
- Okay
- Nice
- Cool
- Thanks

unless they genuinely fit the conversation.

Conversation:
$transcript

Return JSON ONLY:

{
  "replies": [
    "...",
    "...",
    "..."
  ]
}
''';
  }

  List<String> _parseReplies(dynamic replies) {
    if (replies is! List) return [];

    return replies
        .whereType<String>()
        .map((reply) => reply.trim())
        .where((reply) => reply.isNotEmpty)
        .map((reply) => reply.length > 80 ? reply.substring(0, 80) : reply)
        .take(3)
        .toList();
  }

  List<String> _parseRepliesFromText(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) return [];

    try {
      final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      return _parseReplies(parsed['replies']);
    } catch (_) {
      return [];
    }
  }
}
