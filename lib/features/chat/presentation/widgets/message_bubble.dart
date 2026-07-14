import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime createdAt;
  final MessageStatus status;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.createdAt,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(createdAt);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMine
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMine
                        ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(context),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData iconData;
    Color color;

    switch (status) {
      case MessageStatus.sending:
        iconData = Icons.access_time;
        color = Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6);
      case MessageStatus.sent:
      case MessageStatus.delivered:
        iconData = Icons.check;
        color = Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8);
      case MessageStatus.read:
        iconData = Icons.done_all;
        color = Colors.cyanAccent;
      case MessageStatus.failed:
        iconData = Icons.error_outline;
        color = Theme.of(context).colorScheme.errorContainer;
    }

    return Icon(
      iconData,
      size: 14,
      color: color,
    );
  }
}
