import 'package:flutter/material.dart';

class SmartReplyChips extends StatelessWidget {
  final List<String> replies;
  final ValueChanged<String> onSelected;

  const SmartReplyChips({
    super.key,
    required this.replies,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final reply = replies[index];
          return ActionChip(
            label: Text(reply),
            onPressed: () => onSelected(reply),
          );
        },
      ),
    );
  }
}
