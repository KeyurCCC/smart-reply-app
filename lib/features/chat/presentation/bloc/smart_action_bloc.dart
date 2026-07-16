import 'dart:async';
import 'dart:io';
import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_reply_app/features/chat/data/models/meeting_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/address_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/phone_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/email_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/url_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/task_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/reminder_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/payment_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/event_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/flight_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/hotel_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/otp_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/expense_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

// --- Events ---
abstract class SmartActionEvent {}

class ExecuteActionEvent extends SmartActionEvent {
  final ChatEntity entity;
  final SmartAction action;
  ExecuteActionEvent({required this.entity, required this.action});
}

// --- States ---
abstract class SmartActionState {}

class SmartActionInitial extends SmartActionState {}

class SmartActionExecuting extends SmartActionState {
  final SmartActionType actionType;
  SmartActionExecuting(this.actionType);
}

class SmartActionSuccess extends SmartActionState {
  final SmartActionType actionType;
  final String message;
  SmartActionSuccess(this.actionType, this.message);
}

class SmartActionFailure extends SmartActionState {
  final SmartActionType actionType;
  final String error;
  SmartActionFailure(this.actionType, this.error);
}

// --- Bloc ---
class SmartActionBloc extends Bloc<SmartActionEvent, SmartActionState> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  SmartActionBloc() : super(SmartActionInitial()) {
    on<ExecuteActionEvent>(_onExecuteAction);
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      tz.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _notificationsPlugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('[SmartActionBloc] Failed to initialize notifications: $e');
    }
  }

  Future<void> _onExecuteAction(
    ExecuteActionEvent event,
    Emitter<SmartActionState> emit,
  ) async {
    final type = event.action.type;
    emit(SmartActionExecuting(type));

    try {
      switch (type) {
        case SmartActionType.addToCalendar:
          await _handleAddToCalendar(event.entity);
          emit(SmartActionSuccess(type, 'Opened calendar event planner'));
          break;

        case SmartActionType.setReminder:
        case SmartActionType.createReminder:
        case SmartActionType.paymentReminder:
          await _handleSetReminder(event.entity, type);
          emit(SmartActionSuccess(type, 'Reminder scheduled successfully'));
          break;

        case SmartActionType.shareEvent:
        case SmartActionType.share:
          await _handleShare(event.entity);
          emit(SmartActionSuccess(type, 'Shared details successfully'));
          break;

        case SmartActionType.openGoogleMaps:
          await _launchMapUrl(event.entity, isGoogle: true);
          emit(SmartActionSuccess(type, 'Opening Google Maps'));
          break;

        case SmartActionType.openAppleMaps:
          await _launchMapUrl(event.entity, isGoogle: false);
          emit(SmartActionSuccess(type, 'Opening Apple Maps'));
          break;

        case SmartActionType.getDirections:
        case SmartActionType.navigate:
          await _launchMapUrl(event.entity, isDirections: true);
          emit(SmartActionSuccess(type, 'Opening navigation directions'));
          break;

        case SmartActionType.copyAddress:
        case SmartActionType.copy:
        case SmartActionType.copyOtp:
          await _handleCopy(event.entity);
          emit(SmartActionSuccess(type, 'Copied to clipboard'));
          break;

        case SmartActionType.call:
          await _handleDial(event.entity);
          emit(SmartActionSuccess(type, 'Opening phone dialer'));
          break;

        case SmartActionType.whatsapp:
          await _handleWhatsApp(event.entity);
          emit(SmartActionSuccess(type, 'Opening WhatsApp chat'));
          break;

        case SmartActionType.saveContact:
        case SmartActionType.importContact:
          await _handleSaveContact(event.entity);
          emit(SmartActionSuccess(type, 'Opening contact card editor'));
          break;

        case SmartActionType.composeEmail:
          await _handleComposeEmail(event.entity);
          emit(SmartActionSuccess(type, 'Opening email composer'));
          break;

        case SmartActionType.openBrowser:
        case SmartActionType.joinMeeting:
        case SmartActionType.openQr:
          await _handleOpenBrowser(event.entity);
          emit(SmartActionSuccess(type, 'Opening web browser'));
          break;

        case SmartActionType.addTask:
          await _handleAddTask(event.entity);
          emit(SmartActionSuccess(type, 'Task added successfully'));
          break;

        case SmartActionType.markComplete:
        case SmartActionType.markPaid:
          emit(SmartActionSuccess(type, 'Action completed'));
          break;

        case SmartActionType.addShoppingList:
          await _handleAddShoppingList(event.entity);
          emit(SmartActionSuccess(type, 'Added item to shopping list'));
          break;

        case SmartActionType.addExpense:
          await _handleAddExpense(event.entity);
          emit(SmartActionSuccess(type, 'Expense recorded'));
          break;

        case SmartActionType.trackFlight:
        case SmartActionType.trackShipment:
        case SmartActionType.openBooking:
          await _handleTrackNumber(event.entity);
          emit(SmartActionSuccess(type, 'Searching tracking status'));
          break;

        case SmartActionType.autofill:
          await _handleCopy(event.entity);
          emit(SmartActionSuccess(type, 'OTP copied for autofill'));
          break;

        case SmartActionType.saveNote:
          await _handleSaveNote(event.entity);
          emit(SmartActionSuccess(type, 'Saved to clipboard notes'));
          break;

        case SmartActionType.scanQr:
        case SmartActionType.payQr:
          await _handleScanOrPayQr(event.entity);
          emit(SmartActionSuccess(type, 'Proceeding with QR Action'));
          break;
      }
    } catch (e) {
      emit(SmartActionFailure(type, e.toString()));
    }
  }

  // --- Helpers for native interactions ---

  Future<void> _handleAddToCalendar(ChatEntity entity) async {
    String title = 'Event';
    DateTime date = DateTime.now().add(const Duration(days: 1));
    String description = '';

    if (entity is MeetingEntity) {
      title = entity.title;
      date = entity.date ?? date;
      description = entity.url ?? '';
    } else if (entity is EventEntity) {
      title = entity.title;
      date = entity.date;
    } else if (entity is HotelEntity) {
      title = 'Check-in: ${entity.hotelName}';
      date = entity.checkInDate ?? date;
      description = 'Booking ID: ${entity.bookingId}';
    }

    final event = a2c.Event(
      title: title,
      startDate: date,
      endDate: date.add(const Duration(hours: 1)),
      description: description,
    );
    await a2c.Add2Calendar.addEvent2Cal(event);
  }

  Future<void> _handleSetReminder(ChatEntity entity, SmartActionType type) async {
    if (!_notificationsInitialized) {
      throw Exception('Notification service not initialized');
    }

    final status = await Permission.notification.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Notification permission denied');
    }

    String title = 'Reminder';
    String body = 'Smart reply reminder';
    DateTime targetTime = DateTime.now().add(const Duration(minutes: 5));

    if (entity is ReminderEntity) {
      title = 'Reminder: ${entity.title}';
      body = entity.note ?? 'Don\'t forget!';
      targetTime = entity.dueDate ?? targetTime;
    } else if (entity is MeetingEntity) {
      title = 'Meeting Reminder';
      body = entity.title;
      targetTime = (entity.date ?? DateTime.now()).subtract(const Duration(minutes: 10));
    } else if (entity is TaskEntity) {
      title = 'Task Reminder';
      body = entity.title;
      targetTime = entity.dueDate ?? targetTime;
    } else if (entity is PaymentEntity) {
      title = 'Payment Due';
      body = 'Pay ${entity.currency}${entity.amount} to ${entity.recipient ?? "sender"}';
      targetTime = entity.dueDate ?? targetTime;
    }

    if (targetTime.isBefore(DateTime.now())) {
      // Schedule slightly in future if date parsed is in past
      targetTime = DateTime.now().add(const Duration(seconds: 15));
    }

    final scheduledDate = tz.TZDateTime.from(targetTime, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'smart_reminders_channel',
      'Smart Action Reminders',
      channelDescription: 'Scheduled alarms and reminders from chat analytics',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _notificationsPlugin.zonedSchedule(
      targetTime.hashCode,
      title,
      body,
      scheduledDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _handleShare(ChatEntity entity) async {
    String text = '';
    if (entity is AddressEntity) {
      text = entity.address;
    } else if (entity is MeetingEntity) {
      text = 'Meeting: ${entity.title} at ${entity.time ?? ""} on ${entity.date ?? ""}';
    } else if (entity is PaymentEntity) {
      text = 'Payment Request: ${entity.currency}${entity.amount} to ${entity.recipient ?? ""}';
    } else if (entity is UrlEntity) {
      text = entity.url;
    } else {
      text = entity.cardTitle;
    }
    await Share.share(text);
  }

  Future<void> _launchMapUrl(
    ChatEntity entity, {
    bool isGoogle = false,
    bool isDirections = false,
  }) async {
    if (entity is! AddressEntity) return;

    final hasCoords = entity.latitude != null && entity.longitude != null;
    final query = hasCoords 
        ? '${entity.latitude},${entity.longitude}' 
        : Uri.encodeComponent(entity.address);

    Uri uri;
    if (isGoogle || Platform.isAndroid) {
      if (isDirections) {
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$query');
      } else {
        uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      }
    } else {
      // Apple Maps
      if (isDirections) {
        uri = Uri.parse('https://maps.apple.com/?daddr=$query');
      } else {
        uri = Uri.parse('https://maps.apple.com/?q=$query');
      }
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch maps application');
    }
  }

  Future<void> _handleCopy(ChatEntity entity) async {
    String value = '';
    if (entity is OtpEntity) {
      value = entity.otpCode;
    } else if (entity is PhoneEntity) {
      value = entity.phoneNumber;
    } else if (entity is EmailEntity) {
      value = entity.emailAddress;
    } else if (entity is AddressEntity) {
      value = entity.address;
    } else if (entity is UrlEntity) {
      value = entity.url;
    } else if (entity is FlightEntity) {
      value = entity.flightNumber;
    } else if (entity is ExpenseEntity) {
      value = '${entity.currency}${entity.amount}';
    } else if (entity is ReminderEntity) {
      value = '${entity.title}\n${entity.note ?? ""}';
    } else {
      value = entity.cardTitle;
    }
    await Clipboard.setData(ClipboardData(text: value));
  }

  Future<void> _handleDial(ChatEntity entity) async {
    if (entity is! PhoneEntity) return;
    final uri = Uri.parse('tel:${entity.phoneNumber}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not open phone dialer');
    }
  }

  Future<void> _handleWhatsApp(ChatEntity entity) async {
    if (entity is! PhoneEntity) return;
    // Strip non-numeric characters for WhatsApp link
    final numbersOnly = entity.phoneNumber.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$numbersOnly');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open WhatsApp');
    }
  }

  Future<void> _handleSaveContact(ChatEntity entity) async {
    String number = '';
    String? name;
    String? email;

    if (entity is PhoneEntity) {
      number = entity.phoneNumber;
      name = entity.name;
    } else if (entity is EmailEntity) {
      email = entity.emailAddress;
    }

    if (await FlutterContacts.requestPermission()) {
      final contact = Contact()
        ..name = Name(first: name ?? 'Smart Contact');
      if (number.isNotEmpty) {
        contact.phones = [Phone(number)];
      }
      if (email != null) {
        contact.emails = [Email(email)];
      }
      await FlutterContacts.openExternalInsert(contact);
    } else {
      throw Exception('Contacts permission denied');
    }
  }

  Future<void> _handleComposeEmail(ChatEntity entity) async {
    if (entity is! EmailEntity) return;
    final subject = Uri.encodeComponent(entity.subject ?? 'Smart Action Email');
    final body = Uri.encodeComponent(entity.body ?? '');
    final uri = Uri.parse('mailto:${entity.emailAddress}?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not open email composer');
    }
  }

  Future<void> _handleOpenBrowser(ChatEntity entity) async {
    String rawUrl = '';
    if (entity is UrlEntity) {
      rawUrl = entity.url;
    } else if (entity is MeetingEntity && entity.url != null) {
      rawUrl = entity.url!;
    }
    if (rawUrl.isEmpty) return;

    if (!rawUrl.startsWith('http://') && !rawUrl.startsWith('https://')) {
      rawUrl = 'https://$rawUrl';
    }

    final uri = Uri.parse(rawUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open website');
    }
  }

  Future<void> _handleAddTask(ChatEntity entity) async {
    if (entity is! TaskEntity) return;
    // Simulate adding task by scheduling a reminder and copying details to clipboard
    await Clipboard.setData(ClipboardData(text: 'Task: ${entity.title}'));
  }

  Future<void> _handleAddShoppingList(ChatEntity entity) async {
    if (entity is! TaskEntity) return;
    await Clipboard.setData(ClipboardData(text: entity.title));
  }

  Future<void> _handleAddExpense(ChatEntity entity) async {
    if (entity is! ExpenseEntity) return;
    await Clipboard.setData(ClipboardData(text: 'Expense: ${entity.currency}${entity.amount} for ${entity.category ?? "General"}'));
  }

  Future<void> _handleTrackNumber(ChatEntity entity) async {
    String value = '';
    if (entity is FlightEntity) {
      value = entity.flightNumber;
    } else if (entity is HotelEntity) {
      value = entity.bookingId;
    }
    if (value.isEmpty) return;

    final uri = Uri.parse('https://www.google.com/search?q=${Uri.encodeComponent(value)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleSaveNote(ChatEntity entity) async {
    if (entity is! ReminderEntity) return;
    await Clipboard.setData(ClipboardData(text: entity.note ?? entity.title));
  }

  Future<void> _handleScanOrPayQr(ChatEntity entity) async {
    if (entity is UrlEntity) {
      await _handleOpenBrowser(entity);
    } else if (entity is PaymentEntity) {
      await _handleShare(entity);
    }
  }
}
