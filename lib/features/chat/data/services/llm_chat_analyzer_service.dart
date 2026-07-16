// Trigger analysis reload
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/features/chat/data/models/chat_entity_parser.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/services/chat_analyzer_service.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

class LlmChatAnalyzerService implements ChatAnalyzerService {
  final SettingsRepository settingsRepository;
  static const _models = ['gemini-3.1-flash-lite-preview'];

  LlmChatAnalyzerService({required this.settingsRepository});

  @override
  Future<List<ChatEntity>> analyzeMessage({
    required ChatMessage targetMessage,
    required List<ChatMessage> history,
    required String currentUserId,
  }) async {
    final apiKey = await settingsRepository.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('[LlmChatAnalyzer] No API key found for direct analysis.');
      return [];
    }

    try {
      final relationship = await settingsRepository.getRelationshipType();
      final language = await settingsRepository.getPreferredLanguage();
      final tone = await settingsRepository.getChatTone();
      final now = DateTime.now();
      final timezone = now.timeZoneName;
      final locale = Platform.localeName;

      final prompt = _buildPrompt(
        targetMessage: targetMessage,
        history: history,
        relationship: relationship,
        language: language,
        tone: tone,
        timezone: timezone,
        now: now,
        locale: locale,
        currentUserId: currentUserId,
      );

      final parts = <Part>[TextPart(prompt)];

      // Handle image input
      if (targetMessage.type == MessageType.image && targetMessage.text.startsWith('http')) {
        final bytes = await _downloadImageBytes(targetMessage.text);
        if (bytes != null) {
          final lowercaseUrl = targetMessage.text.toLowerCase();
          final mimeType = lowercaseUrl.contains('.png')
              ? 'image/png'
              : lowercaseUrl.contains('.webp')
              ? 'image/webp'
              : 'image/jpeg';
          parts.add(DataPart(mimeType, bytes));
        }
      }

      for (final modelName in _models) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(responseMimeType: 'application/json'),
          );

          final response = await model.generateContent([Content.multi(parts)]);
          final text = response.text?.trim() ?? '';

          final entities = _parseEntitiesFromText(text);
          if (entities.isNotEmpty) {
            return entities;
          }
        } catch (e) {
          debugPrint('[LlmChatAnalyzer] Model $modelName failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[LlmChatAnalyzer] Analysis failed: $e');
    }
    return [];
  }

  String _buildPrompt({
    required ChatMessage targetMessage,
    required List<ChatMessage> history,
    required String relationship,
    required String language,
    required String tone,
    required String timezone,
    required DateTime now,
    required String locale,
    required String currentUserId,
  }) {
    final transcript = history
        .map((msg) {
          final role = msg.senderId == currentUserId ? 'Me' : 'Them';
          final text = msg.type == MessageType.text ? msg.text : '[${msg.type.name} attachment]';
          return '$role: $text';
        })
        .join('\n');

    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return '''
You are a conversation analyzer for a smart messaging app.
Your task is to analyze the LATEST message in the provided conversation history and extract actionable entities.

Target Message to Analyze (sent by ${targetMessage.senderId == currentUserId ? 'Me' : 'Them'}):
"${targetMessage.text}"

Contextual metadata:
- Relationship: $relationship
- Language: $language
- Emotion/Tone: $tone
- Timezone: $timezone
- Current Date: $dateStr
- Current Time: $timeStr
- User Locale: $locale

Conversation History (previous messages for context/resolving pronouns or dates):
$transcript

Instructions:
Extract actionable details from the TARGET MESSAGE. Resolve relative dates/times (e.g. "tomorrow", "Friday") based on Current Date ($dateStr) and Current Time ($timeStr).

Identify the following entity types and construct their respective JSON structures:
1. "meeting": meeting info. Fields: "title" (string), "date" (string YYYY-MM-DD, optional), "time" (string HH:MM, optional), "url" (string, optional)
2. "address": physical address or GPS coordinates (e.g. "23.0216,72.5713"). Fields: "address" (string), "latitude" (number, optional), "longitude" (number, optional)
3. "phone": phone number. Fields: "phoneNumber" (string), "name" (string, optional)
4. "email": email address. Fields: "emailAddress" (string), "subject" (string, optional), "body" (string, optional)
5. "url": website link. Fields: "url" (string), "platform" (string Zoom/Meet/Teams/Website, optional)
6. "task": action task. Fields: "title" (string), "dueDate" (string YYYY-MM-DD HH:MM, optional), "listType" (string "todo" or "shopping", optional)
7. "reminder": reminders. Fields: "title" (string), "dueDate" (string YYYY-MM-DD HH:MM, optional), "note" (string, optional)
8. "payment": payment requests. Fields: "amount" (number), "currency" (string), "dueDate" (string YYYY-MM-DD, optional), "recipient" (string, optional)
9. "event": generic calendar event. Fields: "title" (string), "date" (string YYYY-MM-DD), "time" (string HH:MM, optional)
10. "flight": flight tracking. Fields: "flightNumber" (string), "date" (string YYYY-MM-DD, optional)
11. "hotel": hotel booking. Fields: "hotelName" (string), "bookingId" (string), "address" (string, optional), "checkInDate" (string YYYY-MM-DD, optional)
12. "otp": verification code. Fields: "otpCode" (string)
13. "expense": recorded expenses. Fields: "amount" (number), "currency" (string), "category" (string, optional), "description" (string, optional)

Special Rule for Images:
If the message contains an image and it contains a QR code, decode/extract its URL or text content and represent it as an entity of the appropriate type (e.g. `url` or `payment`). Set "platform" to "qr".

Return a JSON object containing a single list of entities. Example response:
{
  "entities": [
    {
      "type": "meeting",
      "title": "Project Meeting",
      "date": "2026-08-12",
      "time": "15:30"
    }
  ]
}

Only output valid JSON matching the schema above. Do not output markdown, reasoning, or backticks.
''';
  }

  List<ChatEntity> _parseEntitiesFromText(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) return [];

    try {
      final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      final list = parsed['entities'] as List<dynamic>?;
      if (list == null) return [];

      final entities = <ChatEntity>[];
      for (final item in list) {
        final entity = ChatEntityParser.fromJson(Map<String, dynamic>.from(item as Map));
        if (entity != null) {
          entities.add(entity);
        }
      }
      return entities;
    } catch (e) {
      debugPrint('[LlmChatAnalyzer] JSON parse failed: $e');
      return [];
    }
  }

  Future<Uint8List?> _downloadImageBytes(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        return bytes;
      }
    } catch (e) {
      debugPrint('[LlmChatAnalyzer] Failed to download image: $e');
    }
    return null;
  }
}
