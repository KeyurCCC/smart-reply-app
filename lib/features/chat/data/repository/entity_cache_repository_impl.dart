import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_reply_app/features/chat/data/models/chat_entity_parser.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/domain/repository/entity_cache_repository.dart';

class EntityCacheRepositoryImpl implements EntityCacheRepository {
  final SharedPreferences _prefs;
  static const _keyPrefix = 'cached_entities_';

  EntityCacheRepositoryImpl(this._prefs);

  @override
  Future<void> cacheEntities(String messageId, List<ChatEntity> entities) async {
    final listJson = entities.map((e) => e.toJson()).toList();
    await _prefs.setString('$_keyPrefix$messageId', jsonEncode(listJson));
  }

  @override
  Future<List<ChatEntity>?> getCachedEntities(String messageId) async {
    final jsonStr = _prefs.getString('$_keyPrefix$messageId');
    if (jsonStr == null) return null;
    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final list = <ChatEntity>[];
      for (final item in decoded) {
        final parsed = ChatEntityParser.fromJson(Map<String, dynamic>.from(item as Map));
        if (parsed != null) {
          list.add(parsed);
        }
      }
      return list;
    } catch (_) {
      return null;
    }
  }
}
