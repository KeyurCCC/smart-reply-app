import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';

import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;

  StreamSubscription<List<ChatMessage>>? _chatSubscription;

  ChatBloc(this.repository) : super(ChatInitial()) {
    on<LoadChatEvent>(_loadChat);
    on<ReceiveMessagesEvent>(_receiveMessages);
    on<SendMessageEvent>(_sendMessage);
    on<GenerateSmartReplyEvent>(_generateReplies);
    on<DeleteMessageEvent>(_deleteMessage);
    on<ClearSmartRepliesEvent>(_clearSmartReplies);
  }

  @override
  Future<void> close() async {
    await _chatSubscription?.cancel();
    _chatSubscription = null;
    return super.close();
  }

  void _safeAdd(ChatEvent event) {
    if (!isClosed) add(event);
  }

  Future<void> _loadChat(LoadChatEvent event, Emitter<ChatState> emit) async {
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

    _chatSubscription?.cancel();
    _chatSubscription = repository
        .listenMessages(event.conversationId)
        .listen(
      (messages) {
        _safeAdd(ReceiveMessagesEvent(messages));
      },
      onError: (error) {
        emit(ChatError('Messages stream: $error'));
      },
    );
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
    final replies = await repository.generateSmartReplies(event.messages);

    if (state is ChatLoaded) {
      emit(ChatLoaded(messages: current.messages, smartReplies: replies));
    }
  }

  Future<void> _clearSmartReplies(
    ClearSmartRepliesEvent event,
    Emitter<ChatState> emit,
  ) async {
    if (state is ChatLoaded) {
      final current = state as ChatLoaded;
      emit(ChatLoaded(messages: current.messages, smartReplies: const []));
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
