import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class OtpEntity implements ChatEntity {
  final String otpCode;

  OtpEntity({
    required this.otpCode,
  });

  @override
  String get type => 'otp';

  @override
  IconData get icon => Icons.lock_clock;

  @override
  String get cardTitle => 'OTP Code: $otpCode';

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.copyOtp,
          label: 'Copy OTP',
          icon: Icons.copy,
        ),
        const SmartAction(
          type: SmartActionType.autofill,
          label: 'Autofill',
          icon: Icons.edit_attributes,
        ),
      ];

  factory OtpEntity.fromJson(Map<String, dynamic> json) {
    return OtpEntity(
      otpCode: json['otpCode'] as String? ?? json['value'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'otpCode': otpCode,
      };
}
