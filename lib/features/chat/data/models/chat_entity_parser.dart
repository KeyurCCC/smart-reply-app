import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'meeting_entity.dart';
import 'address_entity.dart';
import 'phone_entity.dart';
import 'email_entity.dart';
import 'url_entity.dart';
import 'task_entity.dart';
import 'reminder_entity.dart';
import 'payment_entity.dart';
import 'event_entity.dart';
import 'flight_entity.dart';
import 'hotel_entity.dart';
import 'otp_entity.dart';
import 'expense_entity.dart';

class ChatEntityParser {
  static ChatEntity? fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == null) return null;

    switch (type) {
      case 'meeting':
        return MeetingEntity.fromJson(json);
      case 'address':
        return AddressEntity.fromJson(json);
      case 'phone':
        return PhoneEntity.fromJson(json);
      case 'email':
        return EmailEntity.fromJson(json);
      case 'url':
        return UrlEntity.fromJson(json);
      case 'task':
        return TaskEntity.fromJson(json);
      case 'reminder':
        return ReminderEntity.fromJson(json);
      case 'payment':
        return PaymentEntity.fromJson(json);
      case 'event':
        return EventEntity.fromJson(json);
      case 'flight':
        return FlightEntity.fromJson(json);
      case 'hotel':
        return HotelEntity.fromJson(json);
      case 'otp':
        return OtpEntity.fromJson(json);
      case 'expense':
        return ExpenseEntity.fromJson(json);
      default:
        return null;
    }
  }
}
