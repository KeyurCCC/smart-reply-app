import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:intl/intl.dart';
import 'package:smart_reply_app/core/utils/conversation_id.dart';
import 'package:smart_reply_app/features/users/domain/entities/app_user.dart';
import 'package:smart_reply_app/features/users/domain/repository/user_repository.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/message_input_bar.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/smart_reply_chips.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/typing_indicator.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String partnerName;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.partnerName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatBloc _chatBloc;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatBloc = getIt<ChatBloc>()..add(LoadChatEvent(widget.conversationId));
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _chatBloc.close();
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
      ),
    );
    _controller.clear();

    _typingTimer?.cancel();
    if (_isTyping) {
      _isTyping = false;
      _chatBloc.add(UpdateTypingStatusEvent(widget.conversationId, false));
    }

    Timer(const Duration(milliseconds: 300), () {
      _isSending = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showDeleteMessageDialog(String messageId) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text('Are you sure you want to delete this message for everyone?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _chatBloc.add(
                  DeleteMessageEvent(
                    conversationId: widget.conversationId,
                    messageId: messageId,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
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
    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        appBar: AppBar(
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.teal,
                                fontStyle: FontStyle.italic,
                              ),
                        );
                      }

                      if (user == null) {
                        return const SizedBox.shrink();
                      }

                      if (user.online) {
                        return Text(
                          'online',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                        );
                      } else if (user.lastSeen != null) {
                        final timeString = DateFormat.jm().format(user.lastSeen!);
                        final dateString = DateFormat.MMMd().format(user.lastSeen!);
                        return Text(
                          'last seen $dateString at $timeString',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: state.messages.length + (state.partnerTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.partnerTyping && index == state.messages.length) {
                        return const TypingBubble();
                      }

                      final message = state.messages[index];
                      final isMine = message.senderId == currentUserId;
                      return GestureDetector(
                        onLongPress: isMine
                            ? () => _showDeleteMessageDialog(message.id)
                            : null,
                        child: MessageBubble(
                          text: message.text,
                          isMine: isMine,
                          createdAt: message.createdAt,
                          status: message.status,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoaded && state.isGeneratingSmartReplies) {
                  return const LinearProgressIndicator(minHeight: 2);
                }
                return const SizedBox.shrink();
              },
            ),
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state is ChatLoaded &&
                    state.smartReplyError != null &&
                    state.smartReplies.isEmpty &&
                    !state.isGeneratingSmartReplies) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      state.smartReplyError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                final replies =
                    state is ChatLoaded ? state.smartReplies : const <String>[];
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
            ),
          ],
        ),
      ),
    );
  }
}
