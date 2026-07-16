import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class EventEntity implements ChatEntity {
  final String title;
  final DateTime date;
  final String? time;

  EventEntity({
    required this.title,
    required this.date,
    this.time,
  });

  @override
  String get type => 'event';

  @override
  IconData get icon => Icons.event;

  @override
  String get cardTitle => 'Event: $title';

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.addToCalendar,
          label: 'Add to Calendar',
          icon: Icons.calendar_month,
        ),
        const SmartAction(
          type: SmartActionType.setReminder,
          label: 'Set Reminder',
          icon: Icons.alarm,
        ),
        const SmartAction(
          type: SmartActionType.share,
          label: 'Share Event',
          icon: Icons.share,
        ),
      ];

  factory EventEntity.fromJson(Map<String, dynamic> json) {
    return EventEntity(
      title: json['title'] as String? ?? 'Event',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) ?? DateTime.now() : DateTime.now(),
      time: json['time'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'date': date.toIso8601String().substring(0, 10),
        'time': time,
      };
}
