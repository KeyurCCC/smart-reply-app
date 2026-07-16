import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class PaymentEntity implements ChatEntity {
  final double amount;
  final String currency;
  final DateTime? dueDate;
  final String? recipient;

  PaymentEntity({
    required this.amount,
    required this.currency,
    this.dueDate,
    this.recipient,
  });

  @override
  String get type => 'payment';

  @override
  IconData get icon => Icons.payment;

  @override
  String get cardTitle => recipient != null 
      ? 'Pay $currency$amount to $recipient' 
      : 'Pay $currency$amount';

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.paymentReminder,
          label: 'Payment Reminder',
          icon: Icons.notifications_active,
        ),
        const SmartAction(
          type: SmartActionType.markPaid,
          label: 'Mark Paid',
          icon: Icons.done_all,
        ),
        const SmartAction(
          type: SmartActionType.share,
          label: 'Share Details',
          icon: Icons.share,
        ),
      ];

  factory PaymentEntity.fromJson(Map<String, dynamic> json) {
    return PaymentEntity(
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) ?? 0.0 : 0.0,
      currency: json['currency'] as String? ?? '₹',
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      recipient: json['recipient'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'currency': currency,
        'dueDate': dueDate?.toIso8601String(),
        'recipient': recipient,
      };
}
