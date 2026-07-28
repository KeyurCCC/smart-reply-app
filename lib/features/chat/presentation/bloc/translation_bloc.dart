import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/services/translation_service.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

abstract class TranslationEvent {}

class TranslateMessageEvent extends TranslationEvent {
  final String messageId;
  final String text;
  final String? targetLanguage;

  TranslateMessageEvent({
    required this.messageId,
    required this.text,
    this.targetLanguage,
  });
}

class ToggleAutoTranslateEvent extends TranslationEvent {
  final bool enabled;

  ToggleAutoTranslateEvent(this.enabled);
}

class SetTargetLanguageEvent extends TranslationEvent {
  final String targetLanguage;

  SetTargetLanguageEvent(this.targetLanguage);
}

class ClearTranslationsEvent extends TranslationEvent {}

class TranslationState {
  final Map<String, String> translations;
  final Map<String, bool> loadingMap;
  final bool autoTranslateEnabled;
  final String targetLanguage;

  const TranslationState({
    this.translations = const {},
    this.loadingMap = const {},
    this.autoTranslateEnabled = false,
    this.targetLanguage = 'English',
  });

  TranslationState copyWith({
    Map<String, String>? translations,
    Map<String, bool>? loadingMap,
    bool? autoTranslateEnabled,
    String? targetLanguage,
  }) {
    return TranslationState(
      translations: translations ?? this.translations,
      loadingMap: loadingMap ?? this.loadingMap,
      autoTranslateEnabled: autoTranslateEnabled ?? this.autoTranslateEnabled,
      targetLanguage: targetLanguage ?? this.targetLanguage,
    );
  }
}

class TranslationBloc extends Bloc<TranslationEvent, TranslationState> {
  final TranslationService translationService;
  final SettingsRepository settingsRepository;

  TranslationBloc({
    required this.translationService,
    required this.settingsRepository,
  }) : super(const TranslationState()) {
    on<TranslateMessageEvent>(_onTranslateMessage);
    on<ToggleAutoTranslateEvent>(_onToggleAutoTranslate);
    on<SetTargetLanguageEvent>(_onSetTargetLanguage);
    on<ClearTranslationsEvent>(_onClearTranslations);

    _initSettings();
  }

  Future<void> _initSettings() async {
    final language = await settingsRepository.getPreferredLanguage();
    add(SetTargetLanguageEvent(language));
  }

  Future<void> _onTranslateMessage(
    TranslateMessageEvent event,
    Emitter<TranslationState> emit,
  ) async {
    final lang = event.targetLanguage ?? state.targetLanguage;

    final updatedLoading = Map<String, bool>.from(state.loadingMap);
    updatedLoading[event.messageId] = true;
    emit(state.copyWith(loadingMap: updatedLoading));

    final result = await translationService.translateText(
      text: event.text,
      targetLanguage: lang,
    );

    final newLoading = Map<String, bool>.from(state.loadingMap);
    newLoading.remove(event.messageId);

    final newTranslations = Map<String, String>.from(state.translations);
    newTranslations[event.messageId] = result;

    emit(state.copyWith(
      translations: newTranslations,
      loadingMap: newLoading,
    ));
  }

  void _onToggleAutoTranslate(
    ToggleAutoTranslateEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(state.copyWith(autoTranslateEnabled: event.enabled));
  }

  Future<void> _onSetTargetLanguage(
    SetTargetLanguageEvent event,
    Emitter<TranslationState> emit,
  ) async {
    await settingsRepository.setPreferredLanguage(event.targetLanguage);
    emit(state.copyWith(targetLanguage: event.targetLanguage));
  }

  void _onClearTranslations(
    ClearTranslationsEvent event,
    Emitter<TranslationState> emit,
  ) {
    emit(state.copyWith(translations: {}, loadingMap: {}));
  }
}
