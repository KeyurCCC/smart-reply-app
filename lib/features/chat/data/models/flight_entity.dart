import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class FlightEntity implements ChatEntity {
  final String flightNumber;
  final DateTime? date;

  FlightEntity({
    required this.flightNumber,
    this.date,
  });

  @override
  String get type => 'flight';

  @override
  IconData get icon => Icons.flight;

  @override
  String get cardTitle => 'Flight: $flightNumber';

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.trackFlight,
          label: 'Track Flight',
          icon: Icons.track_changes,
        ),
        const SmartAction(
          type: SmartActionType.setReminder,
          label: 'Set Reminder',
          icon: Icons.alarm,
        ),
        const SmartAction(
          type: SmartActionType.copy,
          label: 'Copy Flight No',
          icon: Icons.copy,
        ),
      ];

  factory FlightEntity.fromJson(Map<String, dynamic> json) {
    return FlightEntity(
      flightNumber: json['flightNumber'] as String? ?? json['value'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'flightNumber': flightNumber,
        'date': date?.toIso8601String().substring(0, 10),
      };
}
