import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class TaskEntity implements ChatEntity {
  final String title;
  final DateTime? dueDate;
  final bool isComplete;
  final String? listType;

  TaskEntity({
    required this.title,
    this.dueDate,
    this.isComplete = false,
    this.listType,
  });

  @override
  String get type => 'task';

  @override
  IconData get icon => listType == 'shopping' ? Icons.shopping_cart : Icons.check_circle_outline;

  @override
  String get cardTitle => listType == 'shopping' ? 'Shopping List: $title' : 'Task: $title';

  @override
  List<SmartAction> get actions {
    if (listType == 'shopping') {
      return [
        const SmartAction(
          type: SmartActionType.addShoppingList,
          label: 'Add to Shopping List',
          icon: Icons.add_shopping_cart,
        ),
        const SmartAction(
          type: SmartActionType.copy,
          label: 'Copy Item',
          icon: Icons.copy,
        ),
      ];
    }

    return [
      const SmartAction(
        type: SmartActionType.addTask,
        label: 'Add Task',
        icon: Icons.add_task,
      ),
      const SmartAction(
        type: SmartActionType.markComplete,
        label: 'Mark Complete',
        icon: Icons.done,
      ),
      const SmartAction(
        type: SmartActionType.setReminder,
        label: 'Set Reminder',
        icon: Icons.alarm,
      ),
    ];
  }

  factory TaskEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['dueDate'] != null) {
      parsedDate = DateTime.tryParse(json['dueDate'] as String);
    }
    return TaskEntity(
      title: json['title'] as String? ?? 'Task',
      dueDate: parsedDate,
      isComplete: json['isComplete'] as bool? ?? false,
      listType: json['listType'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'dueDate': dueDate?.toIso8601String(),
        'isComplete': isComplete,
        'listType': listType,
      };
}
