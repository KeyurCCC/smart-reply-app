import 'package:flutter/material.dart';

class MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final VoidCallback? onAttachPressed;
  final bool isRecording;
  final Duration recordingDuration;
  final VoidCallback? onRecordStart;
  final VoidCallback? onRecordStop;
  final VoidCallback? onRecordCancel;
  final String? replyToText;
  final VoidCallback? onCancelReply;

  const MessageInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.onAttachPressed,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.onRecordStart,
    this.onRecordStop,
    this.onRecordCancel,
    this.replyToText,
    this.onCancelReply,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyToText != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyToText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onCancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                if (!widget.isRecording && widget.onAttachPressed != null) ...[
                  IconButton(
                    onPressed: widget.enabled ? widget.onAttachPressed : null,
                    icon: const Icon(Icons.attach_file),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: widget.isRecording
                      ? Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.mic, color: Theme.of(context).colorScheme.error),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(widget.recordingDuration),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              const Text("Slide to cancel", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_left, color: Colors.grey.shade400),
                            ],
                          ),
                        )
                      : TextField(
                          controller: widget.controller,
                          enabled: widget.enabled,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onSubmitted: (_) {
                            if (_hasText) widget.onSend();
                          },
                        ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: (_) {
                    if (!_hasText && widget.enabled && widget.onRecordStart != null) {
                      widget.onRecordStart!();
                    }
                  },
                  onLongPressEnd: (details) {
                    if (widget.isRecording) {
                      // Simple logic: if user slides left more than 50px, cancel
                      if (details.localPosition.dx < -50) {
                        widget.onRecordCancel?.call();
                      } else {
                        widget.onRecordStop?.call();
                      }
                    }
                  },
                  child: IconButton.filled(
                    onPressed: widget.enabled
                        ? () {
                            if (_hasText) {
                              widget.onSend();
                            }
                          }
                        : null,
                    icon: Icon(_hasText ? Icons.send : Icons.mic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
