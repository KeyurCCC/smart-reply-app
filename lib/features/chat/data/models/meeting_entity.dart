import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class MeetingEntity implements ChatEntity {
  final String title;
  final DateTime? date;
  final String? time;
  final String? url;

  MeetingEntity({
    required this.title,
    this.date,
    this.time,
    this.url,
  });

  @override
  String get type => 'meeting';

  @override
  IconData get icon => Icons.meeting_room;

  @override
  String get cardTitle => 'Meeting: $title';

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.addToCalendar,
          label: 'Add to Calendar',
          icon: Icons.calendar_today,
        ),
        const SmartAction(
          type: SmartActionType.setReminder,
          label: 'Set Reminder',
          icon: Icons.alarm,
        ),
        const SmartAction(
          type: SmartActionType.shareEvent,
          label: 'Share Event',
          icon: Icons.share,
        ),
      ];

  factory MeetingEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'] as String);
    }
    return MeetingEntity(
      title: json['title'] as String? ?? 'Meeting',
      date: parsedDate,
      time: json['time'] as String?,
      url: json['url'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'date': date?.toIso8601String().substring(0, 10),
        'time': time,
        'url': url,
      };
}
