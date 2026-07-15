import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime createdAt;
  final MessageStatus status;
  final MessageType type;
  final String? fileName;
  final int? fileSize;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.createdAt,
    required this.status,
    this.type = MessageType.text,
    this.fileName,
    this.fileSize,
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
            _buildMessageContent(context),
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

  Widget _buildMessageContent(BuildContext context) {
    if (type == MessageType.image) {
      return _buildImageContent(context);
    } else if (type == MessageType.file) {
      return _buildFileContent(context);
    } else {
      return Text(
        text,
        style: TextStyle(
          color: isMine
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
  }

  Widget _buildImageContent(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GestureDetector(
        onTap: () => _launchURL(text),
        child: Image.network(
          text,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 200,
              height: 200,
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 200,
              height: 200,
              color: Colors.black12,
              child: const Icon(Icons.broken_image, size: 40),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFileContent(BuildContext context) {
    final textColor = isMine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    final iconColor = isMine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.primary;
    final sizeText = fileSize != null ? _formatBytes(fileSize!) : '';

    return InkWell(
      onTap: () => _launchURL(text),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: iconColor, size: 36),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName ?? 'Attachment',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (sizeText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sizeText,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, color: textColor.withValues(alpha: 0.7), size: 18),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.bitLength / 10).floor();
    if (i >= suffixes.length) i = suffixes.length - 1;
    var temp = bytes / (1 << (i * 10));
    return "${temp.toStringAsFixed(1)} ${suffixes[i]}";
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[MessageBubble] Could not launch URL: $e');
    }
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
