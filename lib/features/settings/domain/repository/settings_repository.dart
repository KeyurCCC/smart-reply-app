import 'package:smart_reply_app/core/enums/smart_reply_mode.dart';

abstract class SettingsRepository {
  Future<SmartReplyMode> getSmartReplyMode();

  Future<void> setSmartReplyMode(SmartReplyMode mode);

  Future<String?> getGeminiApiKey();

  Future<void> setGeminiApiKey(String? apiKey);
}
