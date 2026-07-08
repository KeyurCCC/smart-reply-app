import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_event.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/chat_state.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/message_input_bar.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/smart_reply_chips.dart';

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

  @override
  void initState() {
    super.initState();
    _chatBloc = getIt<ChatBloc>()..add(LoadChatEvent(widget.conversationId));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _chatBloc.close();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _chatBloc.add(
      SendMessageEvent(
        conversationId: widget.conversationId,
        message: text,
      ),
    );
    _controller.clear();
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _chatBloc,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.partnerName)),
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
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return MessageBubble(
                        text: message.text,
                        isMine: message.senderId == currentUserId,
                        createdAt: message.createdAt,
                      );
                    },
                  );
                },
              ),
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
