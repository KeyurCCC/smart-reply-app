import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

abstract class EntityCacheRepository {
  Future<void> cacheEntities(String messageId, List<ChatEntity> entities);
  Future<List<ChatEntity>?> getCachedEntities(String messageId);
}
