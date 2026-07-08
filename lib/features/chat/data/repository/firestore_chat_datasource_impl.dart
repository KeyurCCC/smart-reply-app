import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_reply_app/core/constants/firestore_constants.dart';
import 'package:smart_reply_app/core/debug/firestore_debug_logger.dart';
import 'package:smart_reply_app/features/chat/data/datasources/firestore_chat_datasource.dart';
import 'package:smart_reply_app/features/chat/data/models/chat_message_model.dart';
import 'package:smart_reply_app/features/chat/data/models/conversation_model.dart';
import 'package:smart_reply_app/features/chat/data/models/inbox_entry_model.dart';

class FirestoreChatDatasourceImpl implements FirestoreChatDatasource {
  final FirebaseFirestore firestore;
  final FirebaseAuth firebaseAuth;

  FirestoreChatDatasourceImpl({
    required this.firestore,
    FirebaseAuth? firebaseAuth,
  }) : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  String? get _authUid => firebaseAuth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _conversationCollection =>
      firestore.collection(FirestoreConstants.conversations);

  CollectionReference<Map<String, dynamic>> _inboxCollection(String userId) {
    return firestore
        .collection(FirestoreConstants.users)
        .doc(userId)
        .collection(FirestoreConstants.inbox);
  }

  CollectionReference<Map<String, dynamic>> _messageCollection(
    String conversationId,
  ) {
    return _conversationCollection
        .doc(conversationId)
        .collection(FirestoreConstants.messages);
  }

  DocumentReference<Map<String, dynamic>> _conversationDoc(
    String conversationId,
  ) {
    return _conversationCollection.doc(conversationId);
  }

  /// Every conversation write MUST include [participants] so Firestore security
  /// rules can evaluate request.resource.data.participants on create/merge, and
  /// resource.data.participants on partial updates.
  Future<void> _writeConversation({
    required String conversationId,
    required List<String> participants,
    required Map<String, dynamic> fields,
  }) async {
    if (participants.isEmpty) {
      throw StateError(
        'Cannot write conversations/$conversationId without participants',
      );
    }

    final docRef = _conversationDoc(conversationId);
    final existing = await docRef.get();

    final payload = {
      'participants': participants,
      ...fields,
    };

    FirestoreDebugLogger.logWrite(
      operation: 'set(merge)',
      path: docRef.path,
      authUid: _authUid,
      participants: participants,
      payload: payload,
      documentExists: existing.exists,
      existingData: existing.data(),
    );

    await docRef.set(payload, SetOptions(merge: true));
  }

  @override
  Stream<List<ConversationModel>> listenConversations(String userId) {
    return _inboxCollection(userId).snapshots().map((snapshot) {
      final conversations = snapshot.docs.map((doc) {
        return InboxEntryModel.fromMap(doc.id, doc.data()).toConversationModel();
      }).toList();
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return conversations;
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

    FirestoreDebugLogger.logRead(
      path: '${_messageCollection(conversationId).path} (listen)',
      authUid: uid,
      documentExists: true,
      data: {'conversationId': conversationId},
    );

    return _messageCollection(conversationId).snapshots().map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessageModel.fromMap(doc.data()))
          .toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
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
    await _messageCollection(conversationId).doc(messageId).delete();
  }

  @override
  Future<void> updateConversation({
    required String conversationId,
    required String lastMessage,
    Map<String, int>? unreadCount,
    required List<String> participants,
  }) async {
    final batch = firestore.batch();
    final now = Timestamp.now();

    final conversationFields = <String, dynamic>{
      'lastMessage': lastMessage,
      'updatedAt': now,
    };
    if (unreadCount != null) {
      conversationFields['unreadCount'] = unreadCount;
    }

    // Conversation doc: always set(merge) with participants — never batch.update.
    final convRef = _conversationDoc(conversationId);
    final existing = await convRef.get();
    final convPayload = {
      'participants': participants,
      ...conversationFields,
    };

    FirestoreDebugLogger.logWrite(
      operation: 'batch.set(merge) conversation',
      path: convRef.path,
      authUid: _authUid,
      participants: participants,
      payload: convPayload,
      documentExists: existing.exists,
      existingData: existing.data(),
    );

    batch.set(convRef, convPayload, SetOptions(merge: true));

    for (final userId in participants) {
      final partnerId = participants.firstWhere((id) => id != userId);
      final inboxRef = _inboxCollection(userId).doc(conversationId);
      final inboxPayload = <String, dynamic>{
        'conversationId': conversationId,
        'partnerId': partnerId,
        'lastMessage': lastMessage,
        'updatedAt': now,
      };
      if (unreadCount != null) {
        inboxPayload['unreadCount'] = unreadCount[userId] ?? 0;
      }

      FirestoreDebugLogger.logWrite(
        operation: 'batch.set(merge) inbox',
        path: inboxRef.path,
        authUid: _authUid,
        participants: participants,
        payload: inboxPayload,
        documentExists: true,
        existingData: null,
      );

      batch.set(inboxRef, inboxPayload, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> updateTypingStatus({
    required String conversationId,
    required bool typing,
  }) async {
    final doc = await _conversationDoc(conversationId).get();
    final participants =
        (doc.data()?['participants'] as List<dynamic>?)?.cast<String>() ?? [];
    if (participants.isEmpty) return;

    await _writeConversation(
      conversationId: conversationId,
      participants: participants,
      fields: {'typing': typing, 'updatedAt': Timestamp.now()},
    );
  }

  @override
  Future<void> markMessageRead({
    required String conversationId,
    required String messageId,
  }) async {
    await _messageCollection(
      conversationId,
    ).doc(messageId).update({'status': 'read'});
  }

  @override
  Future<void> resetUnreadCount({
    required String conversationId,
    required String userId,
    required List<String> participants,
  }) async {
    final batch = firestore.batch();
    final convRef = _conversationDoc(conversationId);
    final existing = await convRef.get();

    final existingUnread =
        (existing.data()?['unreadCount'] as Map<String, dynamic>?) ?? {};
    final unreadCount = <String, int>{
      for (final participant in participants)
        participant: participant == userId
            ? 0
            : (existingUnread[participant] as num?)?.toInt() ?? 0,
    };

    final convPayload = {
      'participants': participants,
      'unreadCount': unreadCount,
      'updatedAt': Timestamp.now(),
    };

    FirestoreDebugLogger.logWrite(
      operation: 'batch.set(merge) resetUnreadCount',
      path: convRef.path,
      authUid: _authUid,
      participants: participants,
      payload: convPayload,
      documentExists: existing.exists,
      existingData: existing.data(),
    );

    batch.set(convRef, convPayload, SetOptions(merge: true));

    final inboxRef = _inboxCollection(userId).doc(conversationId);
    batch.set(
      inboxRef,
      {'unreadCount': 0, 'updatedAt': Timestamp.now()},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getConversation(
    String conversationId,
  ) async {
    final doc = await _conversationDoc(conversationId).get();
    FirestoreDebugLogger.logRead(
      path: doc.reference.path,
      authUid: _authUid,
      documentExists: doc.exists,
      data: doc.data(),
    );
    return doc;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required ChatMessageModel message,
  }) async {
    final path = _messageCollection(conversationId).doc(message.id).path;
    FirestoreDebugLogger.logWrite(
      operation: 'set message',
      path: path,
      authUid: _authUid,
      participants: const [],
      payload: message.toMap(),
      documentExists: false,
      existingData: null,
    );
    await _messageCollection(conversationId).doc(message.id).set(message.toMap());
  }

  @override
  Future<void> ensureConversationSetup({
    required String conversationId,
    required List<String> participants,
  }) async {
    final batch = firestore.batch();
    final now = Timestamp.now();

    final convRef = _conversationDoc(conversationId);
    final existing = await convRef.get();
    final convPayload = {
      'participants': participants,
      'updatedAt': now,
      'typing': false,
      'lastMessage': existing.data()?['lastMessage'] ?? '',
      'unreadCount': existing.data()?['unreadCount'] ??
          {for (final uid in participants) uid: 0},
    };

    FirestoreDebugLogger.logWrite(
      operation: 'ensureConversationSetup conversation',
      path: convRef.path,
      authUid: _authUid,
      participants: participants,
      payload: convPayload,
      documentExists: existing.exists,
      existingData: existing.data(),
    );

    batch.set(convRef, convPayload, SetOptions(merge: true));

    for (final userId in participants) {
      final partnerId = participants.firstWhere((id) => id != userId);
      final inboxRef = _inboxCollection(userId).doc(conversationId);
      final inboxPayload = {
        'conversationId': conversationId,
        'partnerId': partnerId,
        'updatedAt': now,
      };

      FirestoreDebugLogger.logWrite(
        operation: 'ensureConversationSetup inbox',
        path: inboxRef.path,
        authUid: _authUid,
        participants: participants,
        payload: inboxPayload,
        documentExists: false,
        existingData: null,
      );

      batch.set(inboxRef, inboxPayload, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
