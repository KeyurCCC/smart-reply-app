import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class ReminderEntity implements ChatEntity {
  final String title;
  final DateTime? dueDate;
  final String? note;

  ReminderEntity({
    required this.title,
    this.dueDate,
    this.note,
  });

  @override
  String get type => 'reminder';

  @override
  IconData get icon => Icons.alarm;

  @override
  String get cardTitle => 'Reminder: $title';

  @override
  List<SmartAction> get actions {
    final list = [
      const SmartAction(
        type: SmartActionType.createReminder,
        label: 'Create Reminder',
        icon: Icons.notifications_active,
      ),
    ];
    if (note != null && note!.isNotEmpty) {
      list.add(const SmartAction(
        type: SmartActionType.saveNote,
        label: 'Save Note',
        icon: Icons.note_add,
      ));
    }
    list.add(const SmartAction(
      type: SmartActionType.copy,
      label: 'Copy text',
      icon: Icons.copy,
    ));
    return list;
  }

  factory ReminderEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['dueDate'] != null) {
      parsedDate = DateTime.tryParse(json['dueDate'] as String);
    }
    return ReminderEntity(
      title: json['title'] as String? ?? 'Reminder',
      dueDate: parsedDate,
      note: json['note'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'dueDate': dueDate?.toIso8601String(),
        'note': note,
      };
}
