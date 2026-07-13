import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:smart_reply_app/core/di/injection.dart';
import 'package:smart_reply_app/features/auth/domain/repository/auth_repository.dart';
import 'package:smart_reply_app/features/chat/domain/entities/conversation.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/conversations_bloc.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/conversations_event.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/conversations_state.dart';
import 'package:smart_reply_app/features/chat/presentation/pages/chat_page.dart';
import 'package:smart_reply_app/features/settings/presentation/pages/settings_page.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  late final ConversationsBloc _bloc;
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ConversationsBloc>()..add(LoadConversationsEvent());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _bloc.close();
    super.dispose();
  }

  String _partnerName(Conversation conversation) {
    final currentUserId = getIt<AuthRepository>().currentUserId;
    final partner = conversation.participants.firstWhere(
      (user) => user.id != currentUserId,
      orElse: () => conversation.participants.first,
    );
    return partner.name;
  }

  String? _partnerPhoto(Conversation conversation) {
    final currentUserId = getIt<AuthRepository>().currentUserId;
    final partner = conversation.participants.firstWhere(
      (user) => user.id != currentUserId,
      orElse: () => conversation.participants.first,
    );
    return partner.imageUrl;
  }

  Future<void> _showNewChatDialog() async {
    _emailController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Start new chat'),
          content: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Contact email',
              hintText: 'friend@example.com',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                _bloc.add(
                  StartConversationByEmailEvent(_emailController.text),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Start'),
            ),
          ],
        );
      },
    );
  }

  void _openChat(String conversationId, String partnerName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          conversationId: conversationId,
          partnerName: partnerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = getIt<AuthRepository>();
    final user = authRepository.currentUser;

    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<ConversationsBloc, ConversationsState>(
        listener: (context, state) {
          if (state is ConversationStarted) {
            _openChat(state.conversationId, state.partnerName);
          } else if (state is ConversationsActionFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ConversationsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        builder: (context, state) {
          final conversations =
              state is ConversationsLoaded ? state.conversations : <Conversation>[];
          final loading = state is ConversationsLoading;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Chats'),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                ),
                if (user?.photoURL != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CircleAvatar(
                      backgroundImage: NetworkImage(user!.photoURL!),
                    ),
                  ),
                IconButton(
                  onPressed: () => authRepository.signOut(),
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign out',
                ),
              ],
            ),
            body: loading && conversations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : conversations.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations yet.\nTap + to start chatting.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.separated(
                        itemCount: conversations.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = conversations[index];
                          final partnerName = _partnerName(conversation);
                          final photoUrl = _partnerPhoto(conversation);
                          final time = DateFormat.MMMd().add_jm().format(
                                conversation.updatedAt,
                              );

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? Text(partnerName.characters.first)
                                  : null,
                            ),
                            title: Text(partnerName),
                            subtitle: Text(
                              conversation.lastMessage.isEmpty
                                  ? 'No messages yet'
                                  : conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  time,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (conversation.unreadCount > 0) ...[
                                  const SizedBox(height: 4),
                                  CircleAvatar(
                                    radius: 10,
                                    child: Text(
                                      '${conversation.unreadCount}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => _openChat(
                              conversation.id,
                              partnerName,
                            ),
                          );
                        },
                      ),
            floatingActionButton: FloatingActionButton(
              onPressed: _showNewChatDialog,
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}
