// Trigger analysis reload
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/data/models/email_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/phone_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/url_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';
import 'package:smart_reply_app/features/chat/domain/repository/entity_cache_repository.dart';
import 'package:smart_reply_app/features/chat/domain/services/chat_analyzer_service.dart';

// --- Events ---
abstract class ChatAnalyzerEvent {}

class AnalyzeMessagesEvent extends ChatAnalyzerEvent {
  final List<ChatMessage> messages;
  final String currentUserId;
  final String? conversationId;
  AnalyzeMessagesEvent({
    required this.messages,
    required this.currentUserId,
    this.conversationId,
  });
}

class ClearAnalysisEvent extends ChatAnalyzerEvent {}

// --- States ---
abstract class ChatAnalyzerState {
  final Map<String, List<ChatEntity>> messageEntities;
  const ChatAnalyzerState(this.messageEntities);
}

class ChatAnalyzerInitial extends ChatAnalyzerState {
  const ChatAnalyzerInitial() : super(const {});
}

class ChatAnalyzerLoading extends ChatAnalyzerState {
  const ChatAnalyzerLoading(super.messageEntities);
}

class ChatAnalyzerLoaded extends ChatAnalyzerState {
  const ChatAnalyzerLoaded(super.messageEntities);
}

// --- Bloc ---
class ChatAnalyzerBloc extends Bloc<ChatAnalyzerEvent, ChatAnalyzerState> {
  final ChatAnalyzerService analyzerService;
  final EntityCacheRepository cacheRepository;
  final ChatRepository? chatRepository;
  final Set<String> _analyzingMessageIds = {};

  ChatAnalyzerBloc({
    required this.analyzerService,
    required this.cacheRepository,
    this.chatRepository,
  }) : super(const ChatAnalyzerInitial()) {
    on<AnalyzeMessagesEvent>(_onAnalyzeMessages);
    on<ClearAnalysisEvent>(_onClearAnalysis);
  }

  Future<void> _onAnalyzeMessages(
    AnalyzeMessagesEvent event,
    Emitter<ChatAnalyzerState> emit,
  ) async {
    if (event.messages.isEmpty) return;

    final currentEntities = Map<String, List<ChatEntity>>.from(state.messageEntities);
    bool stateChanged = false;

    // 1. First Pass: Resolve entities from Message payload, Local SharedPreferences Cache, or Fast Regex Local Extraction for ALL messages
    for (final message in event.messages) {
      final id = message.id;

      if (!currentEntities.containsKey(id)) {
        // A. Remote entities attached directly to the ChatMessage (from Firebase Realtime DB)
        if (message.entities != null && message.entities!.isNotEmpty) {
          currentEntities[id] = message.entities!;
          await cacheRepository.cacheEntities(id, message.entities!);
          stateChanged = true;
          continue;
        }

        // B. Local SharedPreferences Cache
        final cached = await cacheRepository.getCachedEntities(id);
        if (cached != null) {
          currentEntities[id] = cached;
          stateChanged = true;
          continue;
        }

        // C. Fast Regex Local Extraction (URLs, Phone Numbers, Email Addresses)
        final localEntities = _extractLocalEntities(message);
        if (localEntities.isNotEmpty) {
          currentEntities[id] = localEntities;
          await cacheRepository.cacheEntities(id, localEntities);
          if (event.conversationId != null && chatRepository != null) {
            await chatRepository!.saveMessageEntities(
              conversationId: event.conversationId!,
              messageId: id,
              entities: localEntities,
            );
          }
          stateChanged = true;
        }
      }
    }

    if (stateChanged) {
      emit(ChatAnalyzerLoaded(Map<String, List<ChatEntity>>.from(currentEntities)));
    }

    // 2. Second Pass: Perform live AI extraction for any un-analyzed messages in recent history
    final startIndex = event.messages.length > 10 ? event.messages.length - 10 : 0;
    for (var i = startIndex; i < event.messages.length; i++) {
      final message = event.messages[i];
      final messageId = message.id;

      if (!currentEntities.containsKey(messageId)) {
        if (_analyzingMessageIds.contains(messageId)) {
          continue;
        }
        _analyzingMessageIds.add(messageId);

        emit(ChatAnalyzerLoading(state.messageEntities));

        final historyStart = i >= 9 ? i - 9 : 0;
        final history = event.messages.sublist(historyStart, i + 1);

        final entities = await analyzerService.analyzeMessage(
          targetMessage: message,
          history: history,
          currentUserId: event.currentUserId,
        );

        // Save locally & update state
        await cacheRepository.cacheEntities(messageId, entities);
        currentEntities[messageId] = entities;

        // Persist detected entities to Firebase Realtime Database
        if (entities.isNotEmpty && event.conversationId != null && chatRepository != null) {
          await chatRepository!.saveMessageEntities(
            conversationId: event.conversationId!,
            messageId: messageId,
            entities: entities,
          );
        }

        emit(ChatAnalyzerLoaded(Map<String, List<ChatEntity>>.from(currentEntities)));
        _analyzingMessageIds.remove(messageId);
      }
    }
  }

  List<ChatEntity> _extractLocalEntities(ChatMessage targetMessage) {
    final text = targetMessage.text;
    if (text.isEmpty) return [];

    final entities = <ChatEntity>[];

    // 1. Extract URLs / Links
    final urlRegex = RegExp(
      r'https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9.-]+\.(com|org|net|io|co|dev|in|app|ai|me)(/[^\s]*)?',
      caseSensitive: false,
    );
    final urlMatch = urlRegex.firstMatch(text);
    if (urlMatch != null) {
      var rawUrl = urlMatch.group(0)!;
      var fullUrl = rawUrl;
      if (!fullUrl.startsWith('http://') && !fullUrl.startsWith('https://')) {
        fullUrl = 'https://$fullUrl';
      }
      final lower = fullUrl.toLowerCase();
      String? platform;
      if (lower.contains('meet.google.com')) {
        platform = 'Google Meet';
      } else if (lower.contains('zoom.us')) {
        platform = 'Zoom';
      } else if (lower.contains('teams.microsoft.com')) {
        platform = 'Microsoft Teams';
      } else {
        platform = 'Website';
      }

      entities.add(
        UrlEntity(
          url: fullUrl,
          platform: platform,
        ),
      );
      return entities;
    }

    // 2. Extract Phone Numbers
    final phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
    final phoneMatch = phoneRegex.firstMatch(text);
    if (phoneMatch != null) {
      entities.add(
        PhoneEntity(
          phoneNumber: phoneMatch.group(0)!,
        ),
      );
      return entities;
    }

    // 3. Extract Email Addresses
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final emailMatch = emailRegex.firstMatch(text);
    if (emailMatch != null) {
      entities.add(
        EmailEntity(
          emailAddress: emailMatch.group(0)!,
        ),
      );
      return entities;
    }

    return entities;
  }

  void _onClearAnalysis(
    ClearAnalysisEvent event,
    Emitter<ChatAnalyzerState> emit,
  ) {
    emit(const ChatAnalyzerInitial());
  }
}
