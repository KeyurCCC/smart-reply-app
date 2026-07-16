import 'package:flutter/material.dart';

enum SmartActionType {
  addToCalendar,
  setReminder,
  shareEvent,
  openGoogleMaps,
  openAppleMaps,
  getDirections,
  copyAddress,
  share,
  navigate,
  copy,
  call,
  whatsapp,
  saveContact,
  composeEmail,
  openBrowser,
  joinMeeting,
  createReminder,
  addTask,
  markComplete,
  addShoppingList,
  paymentReminder,
  markPaid,
  addExpense,
  trackFlight,
  openBooking,
  trackShipment,
  copyOtp,
  autofill,
  importContact,
  scanQr,
  openQr,
  payQr,
  saveNote,
}

class SmartAction {
  final SmartActionType type;
  final String label;
  final IconData icon;

  const SmartAction({
    required this.type,
    required this.label,
    required this.icon,
  });
}

abstract class ChatEntity {
  String get type;
  List<SmartAction> get actions;
  IconData get icon;
  String get cardTitle;
  Map<String, dynamic> toJson();
}
