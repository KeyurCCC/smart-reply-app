// Trigger analysis reload
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/repository/entity_cache_repository.dart';
import 'package:smart_reply_app/features/chat/domain/services/chat_analyzer_service.dart';

// --- Events ---
abstract class ChatAnalyzerEvent {}

class AnalyzeMessagesEvent extends ChatAnalyzerEvent {
  final List<ChatMessage> messages;
  final String currentUserId;
  AnalyzeMessagesEvent({required this.messages, required this.currentUserId});
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
  final Set<String> _analyzingMessageIds = {};

  ChatAnalyzerBloc({
    required this.analyzerService,
    required this.cacheRepository,
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

    // 1. Check/load cached entities for all messages in the list
    for (final message in event.messages) {
      final id = message.id;
      if (!currentEntities.containsKey(id)) {
        final cached = await cacheRepository.getCachedEntities(id);
        if (cached != null) {
          currentEntities[id] = cached;
          stateChanged = true;
        }
      }
    }

    if (stateChanged) {
      emit(ChatAnalyzerLoaded(currentEntities));
    }

    // 2. Perform live Gemini extraction for any un-analyzed messages in the last 5 messages
    final startIndex = event.messages.length > 5 ? event.messages.length - 5 : 0;
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

        // Save to Cache
        await cacheRepository.cacheEntities(messageId, entities);

        currentEntities[messageId] = entities;
        emit(ChatAnalyzerLoaded(Map<String, List<ChatEntity>>.from(currentEntities)));
        _analyzingMessageIds.remove(messageId);
      }
    }
  }

  void _onClearAnalysis(
    ClearAnalysisEvent event,
    Emitter<ChatAnalyzerState> emit,
  ) {
    emit(const ChatAnalyzerInitial());
  }
}
