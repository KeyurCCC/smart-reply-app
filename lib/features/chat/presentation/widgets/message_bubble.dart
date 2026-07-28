import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/core/enums/message_type.dart';
import 'package:smart_reply_app/features/chat/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final DateTime createdAt;
  final MessageStatus status;
  final MessageType type;
  final String? fileName;
  final int? fileSize;
  final String? replyToText;
  final bool isForwarded;
  final Map<String, String>? reactions;
  final String? currentUserId;
  final String? translatedText;
  final bool isTranslating;
  final String? targetLanguage;
  final VoidCallback? onReplyTapped;
  final VoidCallback? onImageTapped;
  final ValueChanged<String>? onReactionTapped;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMine,
    required this.createdAt,
    required this.status,
    this.type = MessageType.text,
    this.fileName,
    this.fileSize,
    this.replyToText,
    this.isForwarded = false,
    this.reactions,
    this.currentUserId,
    this.translatedText,
    this.isTranslating = false,
    this.targetLanguage,
    this.onReplyTapped,
    this.onImageTapped,
    this.onReactionTapped,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isForwarded)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forward,
                      size: 12,
                      color: isMine
                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Forwarded',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isMine
                            ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.8)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (replyToText != null)
              GestureDetector(
                onTap: onReplyTapped,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.black26 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isMine ? Colors.white54 : Theme.of(context).colorScheme.primary,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isMine
                          ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            _buildMessageContent(context),
            if (isTranslating)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (translatedText != null && translatedText!.isNotEmpty)
              _buildTranslationBox(context),
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
            if (reactions != null && reactions!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildReactionsBadge(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsBadge(BuildContext context) {
    if (reactions == null || reactions!.isEmpty) return const SizedBox.shrink();

    final counts = <String, int>{};
    for (final emoji in reactions!.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: counts.entries.map((entry) {
        final emoji = entry.key;
        final count = entry.value;
        final isMineReaction = currentUserId != null &&
            reactions![currentUserId] == emoji;

        return GestureDetector(
          onTap: () => onReactionTapped?.call(emoji),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMineReaction
                  ? (isMine ? Colors.white38 : Theme.of(context).colorScheme.primaryContainer)
                  : (isMine ? Colors.black26 : Colors.black12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMineReaction
                    ? (isMine ? Colors.white : Theme.of(context).colorScheme.primary)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                if (count > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isMine
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTranslationBox(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMine ? Colors.black26 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white70 : Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.g_translate,
                size: 14,
                color: isMine
                    ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9)
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Translated (${targetLanguage ?? "EN"})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isMine
                      ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9)
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            translatedText!,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: isMine
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (type == MessageType.image) {
      return _buildImageContent(context);
    } else if (type == MessageType.audio) {
      return _buildAudioContent(context);
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
        onTap: () {
          if (onImageTapped != null) {
            onImageTapped!();
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FullscreenImageViewer(
                  imageUrl: text,
                  title: fileName ?? 'Image',
                ),
              ),
            );
          }
        },
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

  Widget _buildAudioContent(BuildContext context) {
    return _AudioPlayerWidget(url: text, isMine: isMine);
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

class _AudioPlayerWidget extends StatefulWidget {
  final String url;
  final bool isMine;

  const _AudioPlayerWidget({required this.url, required this.isMine});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
    
    _audioPlayer.setSourceUrl(widget.url).catchError((_) {
      // Ignored for now
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: color,
          ),
          onPressed: () {
            if (_isPlaying) {
              _audioPlayer.pause();
            } else {
              _audioPlayer.play(UrlSource(widget.url));
            }
          },
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: color,
                  inactiveTrackColor: color.withValues(alpha: 0.3),
                  thumbColor: color,
                ),
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                  value: _position.inMilliseconds.toDouble().clamp(
                        0.0,
                        _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                      ),
                  onChanged: (val) {
                    _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  "${_formatDuration(_position)} / ${_formatDuration(_duration)}",
                  style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

