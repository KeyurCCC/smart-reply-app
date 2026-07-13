import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';

import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;

  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  String? _conversationId;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 6;

  int _smartReplyGeneration = 0;

  ChatBloc(this.repository) : super(ChatInitial()) {
    on<LoadChatEvent>(_loadChat);
    on<ReceiveMessagesEvent>(_receiveMessages);
    on<SendMessageEvent>(_sendMessage);
    on<GenerateSmartReplyEvent>(_generateReplies);
    on<DeleteMessageEvent>(_deleteMessage);
    on<ClearSmartRepliesEvent>(_clearSmartReplies);
    on<ReconnectChatEvent>(_reconnectChat);
  }

  @override
  Future<void> close() async {
    await _chatSubscription?.cancel();
    _chatSubscription = null;
    _conversationId = null;
    return super.close();
  }

  void _safeAdd(ChatEvent event) {
    if (!isClosed) add(event);
  }

  Future<void> _loadChat(LoadChatEvent event, Emitter<ChatState> emit) async {
    _conversationId = event.conversationId;
    _reconnectAttempts = 0;
    emit(ChatLoading());

    try {
      await repository.ensureAuthReady();
    } catch (e) {
      emit(ChatError('Auth not ready: $e'));
      return;
    }

    try {
      await repository.ensureConversationReady(event.conversationId);
    } catch (e) {
      emit(ChatError('Could not open conversation: $e'));
      return;
    }

    try {
      await repository.markConversationRead(event.conversationId);
    } catch (_) {
      // Non-fatal: still allow reading messages.
    }

    _subscribeToMessages(event.conversationId);
  }

  void _subscribeToMessages(String conversationId) {
    _chatSubscription?.cancel();
    _chatSubscription = repository.listenMessages(conversationId).listen(
      (messages) {
        _reconnectAttempts = 0;
        _safeAdd(ReceiveMessagesEvent(messages));
      },
      onError: (_) {
        _safeAdd(ReconnectChatEvent());
      },
    );
  }

  Future<void> _reconnectChat(
    ReconnectChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    final conversationId = _conversationId;
    if (conversationId == null) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      emit(
        ChatError(
          'Connection lost. Pull down or reopen the chat to retry.',
        ),
      );
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = _reconnectAttempts.clamp(1, 5);
    await Future<void>.delayed(Duration(seconds: delaySeconds));

    try {
      await repository.ensureAuthReady();
    } catch (_) {
      _safeAdd(ReconnectChatEvent());
      return;
    }

    if (isClosed) return;
    _subscribeToMessages(conversationId);
  }

  Future<void> _receiveMessages(
    ReceiveMessagesEvent event,
    Emitter<ChatState> emit,
  ) async {
    final currentUserId = repository.currentUserId;
    emit(ChatLoaded(messages: event.messages));

    final last = event.messages.isNotEmpty ? event.messages.last : null;
    if (last != null &&
        currentUserId != null &&
        last.senderId != currentUserId) {
      _safeAdd(GenerateSmartReplyEvent(event.messages));
    } else {
      _safeAdd(ClearSmartRepliesEvent());
    }
  }

  Future<void> _sendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      _safeAdd(ClearSmartRepliesEvent());
      await repository.ensureAuthReady();
      await repository.sendMessage(
        conversationId: event.conversationId,
        message: event.message,
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> _generateReplies(
    GenerateSmartReplyEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state is! ChatLoaded) return;

    final current = state as ChatLoaded;
    final generation = ++_smartReplyGeneration;

    emit(
      ChatLoaded(
        messages: current.messages,
        smartReplies: current.smartReplies,
        isGeneratingSmartReplies: true,
        smartReplyError: null,
      ),
    );

    final result = await repository.generateSmartReplies(event.messages);
    if (generation != _smartReplyGeneration || state is! ChatLoaded) return;

    emit(
      ChatLoaded(
        messages: current.messages,
        smartReplies: result.replies,
        isGeneratingSmartReplies: false,
        smartReplyError:
            result.replies.isEmpty ? result.error : null,
      ),
    );
  }

  Future<void> _clearSmartReplies(
    ClearSmartRepliesEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state is ChatLoaded) {
      final current = state as ChatLoaded;
      emit(
        ChatLoaded(
          messages: current.messages,
          smartReplies: const [],
          isGeneratingSmartReplies: false,
          smartReplyError: null,
        ),
      );
    }
  }

  Future<void> _deleteMessage(
    DeleteMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    await repository.deleteMessage(
      conversationId: event.conversationId,
      messageId: event.messageId,
    );
  }
}
