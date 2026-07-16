import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class ExpenseEntity implements ChatEntity {
  final double amount;
  final String currency;
  final String? category;
  final String? description;

  ExpenseEntity({
    required this.amount,
    required this.currency,
    this.category,
    this.description,
  });

  @override
  String get type => 'expense';

  @override
  IconData get icon => Icons.account_balance_wallet;

  @override
  String get cardTitle => 'Spent $currency$amount${category != null ? ' on $category' : ''}';

  @override
  List<SmartAction> get actions => [
        const SmartAction(
          type: SmartActionType.addExpense,
          label: 'Add Expense',
          icon: Icons.add_circle_outline,
        ),
        const SmartAction(
          type: SmartActionType.copy,
          label: 'Copy Details',
          icon: Icons.copy,
        ),
      ];

  factory ExpenseEntity.fromJson(Map<String, dynamic> json) {
    return ExpenseEntity(
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) ?? 0.0 : 0.0,
      currency: json['currency'] as String? ?? '₹',
      category: json['category'] as String?,
      description: json['description'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'currency': currency,
        'category': category,
        'description': description,
      };
}
