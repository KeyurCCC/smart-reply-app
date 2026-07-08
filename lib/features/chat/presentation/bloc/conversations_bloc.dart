import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/core/result/result.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';

import 'conversations_event.dart';
import 'conversations_state.dart';

class ConversationsBloc extends Bloc<ConversationsEvent, ConversationsState> {
  final ChatRepository chatRepository;
  final UserRepository userRepository;
  final AuthRepository authRepository;

  StreamSubscription<List<Conversation>>? _subscription;

  ConversationsBloc({
    required this.chatRepository,
    required this.userRepository,
    required this.authRepository,
  }) : super(ConversationsInitial()) {
    on<LoadConversationsEvent>(_onLoad);
    on<ConversationsUpdatedEvent>(_onUpdated);
    on<ConversationsFailedEvent>(_onFailed);
    on<StartConversationByEmailEvent>(_onStartByEmail);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    return super.close();
  }

  void _safeAdd(ConversationsEvent event) {
    if (!isClosed) add(event);
  }

  Future<void> _onLoad(
    LoadConversationsEvent event,
    Emitter<ConversationsState> emit,
  ) async {
    emit(ConversationsLoading());
    await _subscription?.cancel();
    _subscription = null;

    try {
      await authRepository.ensureAuthReady();
      final uid = authRepository.currentUserId;
      if (uid == null) {
        emit(ConversationsError('Not signed in'));
        return;
      }

      _subscription = chatRepository.listenConversations().listen(
        (conversations) =>
            _safeAdd(ConversationsUpdatedEvent(conversations)),
        onError: (error) =>
            _safeAdd(ConversationsFailedEvent(error.toString())),
      );
    } catch (e) {
      emit(ConversationsError(e.toString()));
    }
  }

  void _onUpdated(
    ConversationsUpdatedEvent event,
    Emitter<ConversationsState> emit,
  ) {
    emit(ConversationsLoaded(event.conversations));
  }

  void _onFailed(
    ConversationsFailedEvent event,
    Emitter<ConversationsState> emit,
  ) {
    emit(ConversationsError(event.message));
  }

  Future<void> _onStartByEmail(
    StartConversationByEmailEvent event,
    Emitter<ConversationsState> emit,
  ) async {
    final currentEmail = authRepository.currentUser?.email?.toLowerCase();
    final email = event.email.trim().toLowerCase();

    if (email.isEmpty) {
      emit(ConversationsActionFailure('Enter an email address'));
      return;
    }
    if (currentEmail != null && email == currentEmail) {
      emit(ConversationsActionFailure('You cannot chat with yourself'));
      return;
    }

    final user = await userRepository.findUserByEmail(email);
    if (user == null) {
      emit(ConversationsActionFailure('No user found with that email'));
      return;
    }

    final result = await chatRepository.createConversation([user.id]);
    switch (result) {
      case Success(data: final conversationId):
        emit(ConversationStarted(conversationId, user.displayName));
        _safeAdd(LoadConversationsEvent());
      case Failure(message: final message):
        emit(ConversationsActionFailure(message));
    }
  }
}
