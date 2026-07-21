import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';

// --- Events ---
abstract class SuggestionEvent {}

class GetSuggestionsEvent extends SuggestionEvent {
  final List<ChatMessage> messages;
  GetSuggestionsEvent(this.messages);
}

class ClearSuggestionsEvent extends SuggestionEvent {}

// --- States ---
abstract class SuggestionState {}

class SuggestionInitial extends SuggestionState {}

class SuggestionLoading extends SuggestionState {}

class SuggestionLoaded extends SuggestionState {
  final List<String> replies;
  final String? error;
  SuggestionLoaded(this.replies, {this.error});
}

// --- Bloc ---
class SuggestionBloc extends Bloc<SuggestionEvent, SuggestionState> {
  final ChatRepository repository;
  int _generationId = 0;

  SuggestionBloc(this.repository) : super(SuggestionInitial()) {
    on<GetSuggestionsEvent>(_onGetSuggestions);
    on<ClearSuggestionsEvent>(_onClearSuggestions);
  }

  Future<void> _onGetSuggestions(
    GetSuggestionsEvent event,
    Emitter<SuggestionState> emit,
  ) async {
    if (event.messages.isEmpty) {
      emit(SuggestionInitial());
      return;
    }

    final currentUserId = repository.currentUserId;
    final lastMessage = event.messages.last;

    if (currentUserId != null && lastMessage.senderId == currentUserId) {
      emit(SuggestionInitial());
      return;
    }

    final generation = ++_generationId;
    emit(SuggestionLoading());

    final result = await repository.generateSmartReplies(event.messages);
    if (generation != _generationId) return;

    emit(SuggestionLoaded(
      result.replies,
      error: result.replies.isEmpty ? result.error : null,
    ));
  }

  void _onClearSuggestions(
    ClearSuggestionsEvent event,
    Emitter<SuggestionState> emit,
  ) {
    _generationId++;
    emit(SuggestionInitial());
  }
}
