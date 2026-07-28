import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_analyzer_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/suggestion_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/smart_action_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/translation_bloc.dart';
import 'package:intl/intl.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';
import 'package:smart_reply_app/core/utils/conversation_id.dart';
import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/message_input_bar.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/smart_reply_chips.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/smart_entity_bubble.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String partnerName;

  const ChatPage({super.key, required this.conversationId, required this.partnerName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatBloc _chatBloc;
  late final SuggestionBloc _suggestionBloc;
  late final TranslationBloc _translationBloc;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSending = false;
  ChatMessage? _replyingTo;
  final Map<String, GlobalKey> _messageKeys = {};

  AudioRecorder? _audioRecorder;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  DateTime? _recordStartTime;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _chatBloc = getIt<ChatBloc>()..add(LoadChatEvent(widget.conversationId));
    _suggestionBloc = getIt<SuggestionBloc>();
    _translationBloc = getIt<TranslationBloc>();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _audioRecorder?.dispose();
    _recordingTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _chatBloc.close();
    _suggestionBloc.close();
    _translationBloc.close();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText && !_isTyping) {
      _isTyping = true;
      _chatBloc.add(UpdateTypingStatusEvent(widget.conversationId, true));
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _chatBloc.add(UpdateTypingStatusEvent(widget.conversationId, false));
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _isSending = true;
    _chatBloc.add(
      SendMessageEvent(
        conversationId: widget.conversationId,
        message: text,
        replyToMessageId: _replyingTo?.id,
        replyToText: _replyingTo?.text,
      ),
    );
    _controller.clear();
    setState(() => _replyingTo = null);
    _suggestionBloc.add(ClearSuggestionsEvent());

    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _chatBloc.add(UpdateTypingStatusEvent(widget.conversationId, false));
    }

    Timer(const Duration(milliseconds: 300), () {
      _isSending = false;
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder!.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder!.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        _recordStartTime = DateTime.now();
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_recordStartTime != null) {
            setState(() {
              _recordingDuration = DateTime.now().difference(_recordStartTime!);
            });
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission required')));
        }
      }
    } catch (e) {
      debugPrint('Error starting record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder!.stop();
      _recordingTimer?.cancel();
      _recordStartTime = null;
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      if (path != null) {
        final file = File(path);
        final size = await file.length();

        _chatBloc.add(
          SendMediaMessageEvent(
            conversationId: widget.conversationId,
            localPath: path,
            type: MessageType.audio,
            fileName: 'Voice message',
            fileSize: size,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
    }
  }

  Future<void> _cancelRecording() async {
    try {
      final path = await _audioRecorder!.stop();
      _recordingTimer?.cancel();
      _recordStartTime = null;
      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error canceling record: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _scrollToMessage(String? messageId) {
    if (messageId == null) return;
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  Future<void> _onAttachPressed() async {
    showModalBottomSheet<void>(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Document / File'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      final file = File(picked.path);
      final size = await file.length();
      final fileName = picked.name;

      _chatBloc.add(
        SendMediaMessageEvent(
          conversationId: widget.conversationId,
          localPath: file.path,
          type: MessageType.image,
          fileName: fileName,
          fileSize: size,
        ),
      );
    } catch (e) {
      debugPrint('[ChatPage] Error picking image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final path = pickedFile.path;
      if (path == null) return;

      _chatBloc.add(
        SendMediaMessageEvent(
          conversationId: widget.conversationId,
          localPath: path,
          type: MessageType.file,
          fileName: pickedFile.name,
          fileSize: pickedFile.size,
        ),
      );
    } catch (e) {
      debugPrint('[ChatPage] Error picking file: $e');
    }
  }

  Future<void> _showMessageOptionsBottomSheet(ChatMessage message, bool isMine) async {
    final emojis = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    final currentUserId = _chatBloc.repository.currentUserId;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: emojis.map((emoji) {
                      final isSelected = currentUserId != null &&
                          message.reactions?[currentUserId] == emoji;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _chatBloc.add(
                            ToggleReactionEvent(
                              conversationId: widget.conversationId,
                              messageId: message.id,
                              emoji: emoji,
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    setState(() => _replyingTo = message);
                  },
                ),
                if (message.type == MessageType.text) ...[
                  ListTile(
                    leading: const Icon(Icons.g_translate),
                    title: const Text('Translate Message'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _translationBloc.add(
                        TranslateMessageEvent(
                          messageId: message.id,
                          text: message.text,
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const Text('Copy Text'),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.forward),
                  title: const Text('Forward'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showForwardDialog(message);
                  },
                ),
                if (isMine)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(bottomSheetContext);
                      _chatBloc.add(
                        DeleteMessageEvent(
                          conversationId: widget.conversationId,
                          messageId: message.id,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showForwardDialog(ChatMessage message) async {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Forward to...'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<List<Conversation>>(
              stream: _chatBloc.repository.listenConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final conversations = snapshot.data ?? [];
                if (conversations.isEmpty) {
                  return const Center(child: Text('No conversations found.'));
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    final partner = conv.participants.firstWhere(
                      (p) => p.id != _chatBloc.repository.currentUserId,
                      orElse: () => conv.participants.first,
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: partner.imageUrl != null ? NetworkImage(partner.imageUrl!) : null,
                        child: partner.imageUrl == null ? Text(partner.name[0].toUpperCase()) : null,
                      ),
                      title: Text(partner.name),
                      onTap: () {
                        _chatBloc.repository.sendMessage(
                          conversationId: conv.id,
                          message: message.text,
                          isForwarded: true,
                        );
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message forwarded')));
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _getPartnerId() {
    final currentUserId = _chatBloc.repository.currentUserId;
    final participants = participantsFromConversationId(widget.conversationId);
    return participants.firstWhere((id) => id != currentUserId, orElse: () => '');
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _chatBloc),
        BlocProvider.value(value: _suggestionBloc),
        BlocProvider.value(value: _translationBloc),
        BlocProvider<ChatAnalyzerBloc>(create: (context) => getIt<ChatAnalyzerBloc>()),
        BlocProvider<SmartActionBloc>(create: (context) => getIt<SmartActionBloc>()),
      ],
      child: BlocListener<SmartActionBloc, SmartActionState>(
        listener: (context, state) {
          if (state is SmartActionSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message), behavior: SnackBarBehavior.floating));
          } else if (state is SmartActionFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Action failed: ${state.error}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            actions: [
              BlocBuilder<TranslationBloc, TranslationState>(
                builder: (context, translationState) {
                  return IconButton(
                    tooltip: 'Auto-Translate (${translationState.targetLanguage})',
                    icon: Icon(
                      Icons.g_translate,
                      color: translationState.autoTranslateEnabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      final newAuto = !translationState.autoTranslateEnabled;
                      _translationBloc.add(ToggleAutoTranslateEvent(newAuto));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newAuto
                                ? 'Auto-translate enabled (${translationState.targetLanguage})'
                                : 'Auto-translate disabled',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.partnerName),
                StreamBuilder<AppUser?>(
                  stream: getIt<UserRepository>().listenUser(_getPartnerId()),
                  builder: (context, userSnapshot) {
                    final user = userSnapshot.data;
                    return BlocBuilder<ChatBloc, ChatState>(
                      builder: (context, state) {
                        if (state is ChatLoaded && state.partnerTyping) {
                          return Text(
                            'typing...',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.teal, fontStyle: FontStyle.italic),
                          );
                        }

                        if (user == null) {
                          return const SizedBox.shrink();
                        }

                        if (user.online) {
                          return Text(
                            'online',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
                          );
                        } else if (user.lastSeen != null) {
                          final timeString = DateFormat.jm().format(user.lastSeen!);
                          final dateString = DateFormat.MMMd().format(user.lastSeen!);
                          return Text(
                            'last seen $dateString at $timeString',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: BlocConsumer<ChatBloc, ChatState>(
                  listener: (context, state) {
                    if (state is ChatLoaded) {
                      _scrollToBottom();
                      if (state.messages.isNotEmpty) {
                        final currentUserId = _chatBloc.repository.currentUserId ?? '';
                        context.read<ChatAnalyzerBloc>().add(
                          AnalyzeMessagesEvent(messages: state.messages, currentUserId: currentUserId),
                        );
                        final last = state.messages.last;
                        if (currentUserId.isNotEmpty && last.senderId != currentUserId) {
                          context.read<SuggestionBloc>().add(GetSuggestionsEvent(state.messages));
                        } else {
                          context.read<SuggestionBloc>().add(ClearSuggestionsEvent());
                        }
                      }
                    }
                  },
                  builder: (context, state) {
                    if (state is ChatLoading || state is ChatInitial) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state is ChatError) {
                      return Center(child: Text(state.message));
                    }
                    if (state is! ChatLoaded) {
                      return const SizedBox.shrink();
                    }

                    final currentUserId = _chatBloc.repository.currentUserId;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: state.messages.length + (state.partnerTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (state.partnerTyping && index == 0) {
                          return const TypingBubble();
                        }

                        final messageIndex = state.partnerTyping ? index - 1 : index;
                        final message = state.messages[state.messages.length - 1 - messageIndex];
                        final isMine = message.senderId == currentUserId;
                        return Dismissible(
                          key: ValueKey('dismiss_${message.id}'),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            setState(() => _replyingTo = message);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 16),
                            child: Icon(
                              Icons.reply,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          child: BlocBuilder<ChatAnalyzerBloc, ChatAnalyzerState>(
                            builder: (context, analyzerState) {
                              final entities = analyzerState.messageEntities[message.id] ?? const [];
                              final messageKey = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

                              if (entities.isNotEmpty && message.type == MessageType.text) {
                                return GestureDetector(
                                  key: messageKey,
                                  onLongPress: () => _showMessageOptionsBottomSheet(message, isMine),
                                  child: SmartEntityBubble(
                                    message: message,
                                    entity: entities.first,
                                    isMine: isMine,
                                    onReplyTapped: () => _scrollToMessage(message.replyToMessageId),
                                  ),
                                );
                              }
                              return BlocBuilder<TranslationBloc, TranslationState>(
                                builder: (context, translationState) {
                                  final translatedText = translationState.translations[message.id];
                                  final isTranslating = translationState.loadingMap[message.id] ?? false;

                                  if (translationState.autoTranslateEnabled &&
                                      message.type == MessageType.text &&
                                      !isMine &&
                                      translatedText == null &&
                                      !isTranslating) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _translationBloc.add(
                                        TranslateMessageEvent(
                                          messageId: message.id,
                                          text: message.text,
                                        ),
                                      );
                                    });
                                  }

                                  return GestureDetector(
                                    key: messageKey,
                                    onLongPress: () => _showMessageOptionsBottomSheet(message, isMine),
                                    child: MessageBubble(
                                      text: message.text,
                                      isMine: isMine,
                                      createdAt: message.createdAt,
                                      status: message.status,
                                      type: message.type,
                                      fileName: message.fileName,
                                      fileSize: message.fileSize,
                                      replyToText: message.replyToText,
                                      isForwarded: message.isForwarded ?? false,
                                      reactions: message.reactions,
                                      currentUserId: currentUserId,
                                      translatedText: translatedText,
                                      isTranslating: isTranslating,
                                      targetLanguage: translationState.targetLanguage,
                                      onReplyTapped: () => _scrollToMessage(message.replyToMessageId),
                                      onReactionTapped: (emoji) {
                                        _chatBloc.add(
                                          ToggleReactionEvent(
                                            conversationId: widget.conversationId,
                                            messageId: message.id,
                                            emoji: emoji,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              BlocBuilder<SuggestionBloc, SuggestionState>(
                builder: (context, state) {
                  if (state is SuggestionLoading) {
                    return const LinearProgressIndicator(minHeight: 2);
                  }
                  return const SizedBox.shrink();
                },
              ),
              BlocBuilder<SuggestionBloc, SuggestionState>(
                builder: (context, state) {
                  if (state is SuggestionLoaded && state.error != null && state.replies.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        state.error!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              BlocBuilder<SuggestionBloc, SuggestionState>(
                builder: (context, state) {
                  final replies = state is SuggestionLoaded ? state.replies : const <String>[];
                  return SmartReplyChips(
                    replies: replies,
                    onSelected: (reply) {
                      _controller.text = reply;
                      _sendMessage();
                    },
                  );
                },
              ),
              MessageInputBar(
                controller: _controller,
                onSend: _sendMessage,
                onAttachPressed: _onAttachPressed,
                isRecording: _isRecording,
                recordingDuration: _recordingDuration,
                onRecordStart: _startRecording,
                onRecordStop: _stopRecording,
                onRecordCancel: _cancelRecording,
                replyToText: _replyingTo?.text,
                onCancelReply: () => setState(() => _replyingTo = null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
