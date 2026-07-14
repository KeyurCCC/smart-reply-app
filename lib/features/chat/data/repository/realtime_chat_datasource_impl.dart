import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smart_reply_app/core/utils/conversation_id.dart';
import 'package:smart_reply_app/features/chat/data/datasources/realtime_chat_datasource.dart';
import 'package:smart_reply_app/features/chat/data/models/chat_message_model.dart';
import 'package:smart_reply_app/features/chat/data/models/conversation_model.dart';
import 'package:smart_reply_app/features/chat/data/models/inbox_entry_model.dart';

class RealtimeChatDatasourceImpl implements RealtimeChatDatasource {
  final FirebaseDatabase database;
  final FirebaseAuth firebaseAuth;

  RealtimeChatDatasourceImpl({
    required this.database,
    FirebaseAuth? firebaseAuth,
  }) : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  String? get _authUid => firebaseAuth.currentUser?.uid;

  @override
  Stream<List<ConversationModel>> listenConversations(String userId) {
    return database.ref('inboxes/$userId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return [];

      final list = <ConversationModel>[];
      data.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          list.add(
            InboxEntryModel.fromMap(key.toString(), map).toConversationModel(),
          );
        }
      });
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  @override
  Stream<List<ChatMessageModel>> listenMessages(String conversationId) {
    final uid = _authUid;
    if (uid == null) {
      return Stream.error(
        StateError('listenMessages: FirebaseAuth.currentUser is null'),
      );
    }

    return database.ref('messages/$conversationId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return [];

      final list = <ChatMessageModel>[];
      data.forEach((key, value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          list.add(ChatMessageModel.fromMap(map));
        }
      });
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  @override
  Future<String> createConversation({
    required String conversationId,
    required List<String> participants,
  }) {
    return ensureConversationSetup(
      conversationId: conversationId,
      participants: participants,
    ).then((_) => conversationId);
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await database.ref('messages/$conversationId/$messageId').remove();
  }

  @override
  Future<void> updateConversation({
    required String conversationId,
    required String lastMessage,
    Map<String, int>? unreadCount,
    required List<String> participants,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> updates = {};

    updates['conversations/$conversationId/lastMessage'] = lastMessage;
    updates['conversations/$conversationId/updatedAt'] = now;
    updates['conversations/$conversationId/participants'] = participants;
    if (unreadCount != null) {
      updates['conversations/$conversationId/unreadCount'] = unreadCount;
    }

    for (final userId in participants) {
      final partnerId = participants.firstWhere((id) => id != userId);

      updates['inboxes/$userId/$conversationId/conversationId'] =
          conversationId;
      updates['inboxes/$userId/$conversationId/partnerId'] = partnerId;
      updates['inboxes/$userId/$conversationId/lastMessage'] = lastMessage;
      updates['inboxes/$userId/$conversationId/updatedAt'] = now;
      if (unreadCount != null) {
        updates['inboxes/$userId/$conversationId/unreadCount'] =
            unreadCount[userId] ?? 0;
      }
    }

    await database.ref().update(updates);
  }

  @override
  Future<void> updateTypingStatus({
    required String conversationId,
    required String userId,
    required bool typing,
  }) async {
    final typingRef = database.ref('conversations/$conversationId/typing/$userId');
    final timeRef = database.ref('conversations/$conversationId/updatedAt');

    final now = DateTime.now().millisecondsSinceEpoch;
    if (typing) {
      await typingRef.set(true);
      await timeRef.set(now);
      await typingRef.onDisconnect().set(false);
    } else {
      await typingRef.set(false);
      await timeRef.set(now);
      await typingRef.onDisconnect().cancel();
    }
  }

  @override
  Stream<bool> listenTypingStatus({
    required String conversationId,
    required String partnerId,
  }) {
    return database
        .ref('conversations/$conversationId/typing/$partnerId')
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      return value == true;
    });
  }

  @override
  Future<void> markMessageRead({
    required String conversationId,
    required String messageId,
  }) async {
    await database
        .ref('messages/$conversationId/$messageId')
        .update({'status': 'read'});
  }

  @override
  Future<void> markMessagesAsRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final Map<String, dynamic> updates = {};
    for (final id in messageIds) {
      updates['messages/$conversationId/$id/status'] = 'read';
    }
    await database.ref().update(updates);
  }

  @override
  Future<void> resetUnreadCount({
    required String conversationId,
    required String userId,
    required List<String> participants,
  }) async {
    final existing = await getConversation(conversationId);
    final existingUnread = (existing?['unreadCount'] as Map?) ?? {};

    final unreadCount = <String, int>{
      for (final participant in participants)
        participant: participant == userId
            ? 0
            : (existingUnread[participant] as num?)?.toInt() ?? 0,
    };

    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> updates = {
      'conversations/$conversationId/unreadCount': unreadCount,
      'conversations/$conversationId/updatedAt': now,
      'inboxes/$userId/$conversationId/unreadCount': 0,
      'inboxes/$userId/$conversationId/updatedAt': now,
    };

    await database.ref().update(updates);
  }

  @override
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    final snapshot = await database.ref('conversations/$conversationId').get();
    if (!snapshot.exists) return null;
    final value = snapshot.value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required ChatMessageModel message,
  }) async {
    final userId = message.senderId;
    final participants = participantsFromConversationId(conversationId);
    if (participants.length < 2) {
      await database.ref('messages/$conversationId/${message.id}').set(message.toMap());
      return;
    }

    final partnerId = participants.firstWhere((id) => id != userId);
    final now = message.createdAt.millisecondsSinceEpoch;

    final Map<String, dynamic> updates = {};
    updates['messages/$conversationId/${message.id}'] = message.toMap();

    updates['conversations/$conversationId/lastMessage'] = message.text;
    updates['conversations/$conversationId/updatedAt'] = now;
    updates['conversations/$conversationId/unreadCount/$partnerId'] = ServerValue.increment(1);
    updates['conversations/$conversationId/unreadCount/$userId'] = 0;

    updates['inboxes/$userId/$conversationId/lastMessage'] = message.text;
    updates['inboxes/$userId/$conversationId/updatedAt'] = now;
    updates['inboxes/$userId/$conversationId/unreadCount'] = 0;

    updates['inboxes/$partnerId/$conversationId/lastMessage'] = message.text;
    updates['inboxes/$partnerId/$conversationId/updatedAt'] = now;
    updates['inboxes/$partnerId/$conversationId/unreadCount'] = ServerValue.increment(1);

    await database.ref().update(updates);
  }

  @override
  Future<void> ensureConversationSetup({
    required String conversationId,
    required List<String> participants,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final convSnapshot =
        await database.ref('conversations/$conversationId').get();
    final Map<dynamic, dynamic>? existingData =
        convSnapshot.value as Map<dynamic, dynamic>?;
    final lastMessage = existingData?['lastMessage'] ?? '';
    final unreadCount = existingData?['unreadCount'] ??
        {for (final uid in participants) uid: 0};

    final Map<String, dynamic> updates = {};

    updates['conversations/$conversationId'] = {
      'id': conversationId,
      'participants': participants,
      'updatedAt': now,
      'typing': existingData?['typing'] ?? false,
      'lastMessage': lastMessage,
      'unreadCount': unreadCount,
    };

    for (final userId in participants) {
      final partnerId = participants.firstWhere((id) => id != userId);
      updates['inboxes/$userId/$conversationId'] = {
        'conversationId': conversationId,
        'partnerId': partnerId,
        'lastMessage': lastMessage,
        'updatedAt': now,
        'unreadCount': (unreadCount as Map)[userId] ?? 0,
      };
    }

    await database.ref().update(updates);
  }
}
