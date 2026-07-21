import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/core/result/result.dart';
import 'package:smart_reply_app/core/utils/conversation_id.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/chat/data/datasources/realtime_chat_datasource.dart';
import 'package:smart_reply_app/features/chat/data/models/chat_message_model.dart';
import 'package:smart_reply_app/features/chat/domain/entities/smart_reply_result.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_user.dart';
import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';
import 'package:smart_reply_app/features/chat/domain/repository/chat_repository.dart';
import 'package:smart_reply_app/features/chat/domain/services/smart_reply_provider.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';
import 'package:uuid/uuid.dart';

class ChatRepositoryImpl implements ChatRepository {
  final RealtimeChatDatasource datasource;
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final SmartReplyProvider smartReplyProvider;
  final Uuid uuid;

  ChatRepositoryImpl({
    required this.datasource,
    required this.authRepository,
    required this.userRepository,
    required this.smartReplyProvider,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  String? get _currentUserId => authRepository.currentUserId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Stream<List<Conversation>> listenConversations() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(const []);
    }

    return datasource.listenConversations(userId).asyncMap((models) async {
      final conversations = <Conversation>[];
      for (final model in models) {
        final partnerId = model.partnerId.isNotEmpty
            ? model.partnerId
            : model.participantIds.firstWhere(
                (id) => id != userId,
                orElse: () => '',
              );
        if (partnerId.isEmpty) continue;

        final partner = await userRepository.getUser(partnerId);
        conversations.add(
          Conversation(
            id: model.id,
            participants: [
              ChatUser(
                id: userId,
                name: authRepository.currentUser?.displayName ?? 'You',
                imageUrl: authRepository.currentUser?.photoURL,
              ),
              ChatUser(
                id: partnerId,
                name: partner?.displayName ?? 'User',
                imageUrl: partner?.photoUrl,
              ),
            ],
            lastMessage: model.lastMessage,
            updatedAt: model.updatedAt,
            typing: model.typing,
            unreadCount: model.unreadCount,
          ),
        );
      }
      return conversations;
    });
  }

  @override
  Stream<List<ChatMessage>> listenMessages(String conversationId) {
    return authRepository.ensureAuthReady().asStream().asyncExpand((_) {
      return datasource
          .listenMessages(conversationId)
          .map((models) => models.cast<ChatMessage>().toList());
    });
  }

  @override
  Future<Result<String>> createConversation(List<String> participants) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const Failure('Not signed in');
      }

      final allParticipants = {...participants, userId}.toList();
      if (allParticipants.length != 2) {
        return const Failure('Only 1:1 conversations are supported');
      }

      final conversationId = conversationIdFor(
        allParticipants[0],
        allParticipants[1],
      );

      await datasource.ensureConversationSetup(
        conversationId: conversationId,
        participants: allParticipants,
      );

      return Success(conversationId);
    } catch (e) {
      return Failure(e.toString(), error: e);
    }
  }

  /// Resolves participants from Realtime Database, falling back to parsing the
  /// deterministic conversationId when the doc is missing or unreadable.
  Future<List<String>> _participantsFor(String conversationId) async {
    final userId = _currentUserId;
    try {
      final conversationDoc = await datasource.getConversation(conversationId);
      final fromDoc =
          (conversationDoc?['participants'] as List<dynamic>?)
              ?.cast<String>() ??
          [];
      if (fromDoc.length >= 2) return fromDoc;
    } catch (_) {
      // Fall through to ID parsing if read is denied or doc is incomplete.
    }

    final fromId = participantsFromConversationId(conversationId);
    if (fromId.length >= 2) return fromId;

    if (userId != null && fromId.length == 1 && !fromId.contains(userId)) {
      return [...fromId, userId];
    }

    return fromId;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String message,
    String? replyToMessageId,
    String? replyToText,
    bool? isForwarded,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Not signed in');
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final chatMessage = ChatMessageModel(
      id: uuid.v4(),
      senderId: userId,
      text: trimmed,
      type: MessageType.text,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      replyToMessageId: replyToMessageId,
      replyToText: replyToText,
      isForwarded: isForwarded,
    );

    await datasource.sendMessage(
      conversationId: conversationId,
      message: chatMessage,
    );
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) {
    return datasource.deleteMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  @override
  Future<SmartReplyResult> generateSmartReplies(List<ChatMessage> messages) {
    final userId = _currentUserId;
    if (userId == null) {
      return Future.value(const SmartReplyResult());
    }

    return smartReplyProvider.generateReplies(
      messages: messages,
      currentUserId: userId,
    );
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final participants = await _participantsFor(conversationId);
    if (participants.length < 2) return;

    await datasource.resetUnreadCount(
      conversationId: conversationId,
      userId: userId,
      participants: participants,
    );
  }

  @override
  Future<void> ensureConversationReady(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    final participants = await _participantsFor(conversationId);
    if (participants.length < 2) {
      throw StateError(
        'Cannot open conversation: participants unresolved for $conversationId',
      );
    }

    await datasource.ensureConversationSetup(
      conversationId: conversationId,
      participants: participants,
    );
  }

  @override
  Future<void> ensureAuthReady() {
    return authRepository.ensureAuthReady();
  }

  @override
  Future<void> updateTypingStatus({
    required String conversationId,
    required bool typing,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;
    return datasource.updateTypingStatus(
      conversationId: conversationId,
      userId: userId,
      typing: typing,
    );
  }

  @override
  Stream<bool> listenTypingStatus({
    required String conversationId,
    required String partnerId,
  }) {
    return datasource.listenTypingStatus(
      conversationId: conversationId,
      partnerId: partnerId,
    );
  }

  @override
  Future<void> markMessagesAsRead(String conversationId, List<String> messageIds) {
    return datasource.markMessagesAsRead(
      conversationId: conversationId,
      messageIds: messageIds,
    );
  }

  @override
  Future<Result<String>> uploadFile({
    required String localPath,
    required String remotePath,
  }) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(remotePath);
      final uploadTask = ref.putFile(File(localPath));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return Success(downloadUrl);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  @override
  Future<void> sendMediaMessage({
    required String conversationId,
    required String mediaUrl,
    required MessageType type,
    String? fileName,
    int? fileSize,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Not signed in');
    }

    final chatMessage = ChatMessageModel(
      id: uuid.v4(),
      senderId: userId,
      text: mediaUrl,
      type: type,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
      fileName: fileName,
      fileSize: fileSize,
    );

    await datasource.sendMessage(
      conversationId: conversationId,
      message: chatMessage,
    );
  }
}
