import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reply_app/core/enums/smart_reply_mode.dart';
import 'package:smart_reply_app/features/settings/domain/repository/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  static const _smartReplyModeKey = 'smart_reply_mode';
  static const _geminiApiKeyKey = 'gemini_api_key';
  static const _relationshipTypeKey = 'relationship_type';
  static const _preferredLanguageKey = 'preferred_language';
  static const _chatToneKey = 'chat_tone';

  final SharedPreferences _prefs;

  SettingsRepositoryImpl(this._prefs);

  @override
  Future<SmartReplyMode> getSmartReplyMode() async {
    final value = _prefs.getString(_smartReplyModeKey);
    return SmartReplyMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => SmartReplyMode.mlKit,
    );
  }

  @override
  Future<void> setSmartReplyMode(SmartReplyMode mode) {
    return _prefs.setString(_smartReplyModeKey, mode.name);
  }

  @override
  Future<String?> getGeminiApiKey() async {
    final stored = _prefs.getString(_geminiApiKeyKey);
    if (stored != null && stored.isNotEmpty) return stored;

    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;

    return null;
  }

  @override
  Future<void> setGeminiApiKey(String? apiKey) {
    if (apiKey == null || apiKey.trim().isEmpty) {
      return _prefs.remove(_geminiApiKeyKey);
    }
    return _prefs.setString(_geminiApiKeyKey, apiKey.trim());
  }

  @override
  Future<String> getRelationshipType() async {
    return _prefs.getString(_relationshipTypeKey) ?? 'friend';
  }

  @override
  Future<void> setRelationshipType(String type) {
    return _prefs.setString(_relationshipTypeKey, type);
  }

  @override
  Future<String> getPreferredLanguage() async {
    return _prefs.getString(_preferredLanguageKey) ?? 'English';
  }

  @override
  Future<void> setPreferredLanguage(String language) {
    return _prefs.setString(_preferredLanguageKey, language);
  }

  @override
  Future<String> getChatTone() async {
    return _prefs.getString(_chatToneKey) ?? 'casual';
  }

  @override
  Future<void> setChatTone(String tone) {
    return _prefs.setString(_chatToneKey, tone);
  }
}
