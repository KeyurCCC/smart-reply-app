import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/result/result.dart';
import 'package:smart_reply_app/core/utils/conversation_id.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';

import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;

  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  StreamSubscription<bool>? _typingSubscription;
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
    on<UpdateTypingStatusEvent>(_updateTypingStatus);
    on<ReceiveTypingStatusEvent>(_receiveTypingStatus);
    on<SendMediaMessageEvent>(_sendMediaMessage);
  }

  @override
  Future<void> close() async {
    await _chatSubscription?.cancel();
    _chatSubscription = null;
    await _typingSubscription?.cancel();
    _typingSubscription = null;
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

    final participants = participantsFromConversationId(event.conversationId);
    final partnerId = participants.firstWhere(
      (id) => id != repository.currentUserId,
      orElse: () => '',
    );
    if (partnerId.isNotEmpty) {
      _subscribeToTyping(event.conversationId, partnerId);
    }
  }

  void _subscribeToMessages(String conversationId) {
    _chatSubscription?.cancel();
    _chatSubscription = repository
        .listenMessages(conversationId)
        .listen(
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

    bool isPartnerTyping = false;
    if (state is ChatLoaded) {
      isPartnerTyping = (state as ChatLoaded).partnerTyping;
    }

    emit(
      ChatLoaded(
        messages: event.messages,
        partnerTyping: isPartnerTyping,
      ),
    );

    if (currentUserId != null && _conversationId != null) {
      final unreadMessageIds = event.messages
          .where((m) => m.senderId != currentUserId && m.status != MessageStatus.read)
          .map((m) => m.id)
          .toList();
      if (unreadMessageIds.isNotEmpty) {
        repository.markMessagesAsRead(_conversationId!, unreadMessageIds);
      }
    }

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
        replyToMessageId: event.replyToMessageId,
        replyToText: event.replyToText,
        isForwarded: event.isForwarded,
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

  void _subscribeToTyping(String conversationId, String partnerId) {
    _typingSubscription?.cancel();
    _typingSubscription = repository
        .listenTypingStatus(
      conversationId: conversationId,
      partnerId: partnerId,
    )
        .listen((isTyping) {
      _safeAdd(ReceiveTypingStatusEvent(isTyping));
    });
  }

  Future<void> _updateTypingStatus(
    UpdateTypingStatusEvent event,
    Emitter<ChatState> emit,
  ) async {
    await repository.updateTypingStatus(
      conversationId: event.conversationId,
      typing: event.typing,
    );
  }

  void _receiveTypingStatus(
    ReceiveTypingStatusEvent event,
    Emitter<ChatState> emit,
  ) {
    if (state is ChatLoaded) {
      final current = state as ChatLoaded;
      emit(
        ChatLoaded(
          messages: current.messages,
          smartReplies: current.smartReplies,
          isGeneratingSmartReplies: current.isGeneratingSmartReplies,
          smartReplyError: current.smartReplyError,
          partnerTyping: event.isTyping,
        ),
      );
    }
  }

  Future<void> _sendMediaMessage(
    SendMediaMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      _safeAdd(ClearSmartRepliesEvent());
      final uuidStr = const Uuid().v4();
      final remotePath = 'chat_attachments/${event.conversationId}/${uuidStr}_${event.fileName}';

      final uploadResult = await repository.uploadFile(
        localPath: event.localPath,
        remotePath: remotePath,
      );

      switch (uploadResult) {
        case Success(data: final mediaUrl):
          await repository.sendMediaMessage(
            conversationId: event.conversationId,
            mediaUrl: mediaUrl,
            type: event.type,
            fileName: event.fileName,
            fileSize: event.fileSize,
          );
        case Failure(message: final error):
          emit(ChatError('Failed to upload attachment: $error'));
      }
    } catch (e) {
      emit(ChatError('Failed to send media message: $e'));
    }
  }
}
