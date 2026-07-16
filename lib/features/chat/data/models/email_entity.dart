import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class EmailEntity implements ChatEntity {
  final String emailAddress;
  final String? subject;
  final String? body;

  EmailEntity({
    required this.emailAddress,
    this.subject,
    this.body,
  });

  @override
  String get type => 'email';

  @override
  IconData get icon => Icons.email;

  @override
  String get cardTitle => emailAddress;

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.composeEmail,
          label: 'Compose Email',
          icon: Icons.edit,
        ),
        const SmartAction(
          type: SmartActionType.copy,
          label: 'Copy Email',
          icon: Icons.copy,
        ),
        const SmartAction(
          type: SmartActionType.saveContact,
          label: 'Save Contact',
          icon: Icons.contact_mail,
        ),
      ];

  factory EmailEntity.fromJson(Map<String, dynamic> json) {
    return EmailEntity(
      emailAddress: json['emailAddress'] as String? ?? json['value'] as String? ?? '',
      subject: json['subject'] as String?,
      body: json['body'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'emailAddress': emailAddress,
        'subject': subject,
        'body': body,
      };
}
