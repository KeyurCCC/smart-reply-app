import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class PhoneEntity implements ChatEntity {
  final String phoneNumber;
  final String? name;

  PhoneEntity({
    required this.phoneNumber,
    this.name,
  });

  @override
  String get type => 'phone';

  @override
  IconData get icon => Icons.phone;

  @override
  String get cardTitle => name != null ? '$name: $phoneNumber' : phoneNumber;

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.call,
          label: 'Call',
          icon: Icons.call,
        ),
        const SmartAction(
          type: SmartActionType.whatsapp,
          label: 'WhatsApp',
          icon: Icons.chat_bubble_outline,
        ),
        const SmartAction(
          type: SmartActionType.saveContact,
          label: 'Save Contact',
          icon: Icons.contact_phone,
        ),
        const SmartAction(
          type: SmartActionType.copy,
          label: 'Copy Number',
          icon: Icons.copy,
        ),
      ];

  factory PhoneEntity.fromJson(Map<String, dynamic> json) {
    return PhoneEntity(
      phoneNumber: json['phoneNumber'] as String? ?? json['value'] as String? ?? '',
      name: json['name'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'phoneNumber': phoneNumber,
        'name': name,
      };
}
