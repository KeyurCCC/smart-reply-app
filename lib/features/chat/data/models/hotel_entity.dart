import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class HotelEntity implements ChatEntity {
  final String hotelName;
  final String bookingId;
  final String? address;
  final DateTime? checkInDate;

  HotelEntity({
    required this.hotelName,
    required this.bookingId,
    this.address,
    this.checkInDate,
  });

  @override
  String get type => 'hotel';

  @override
  IconData get icon => Icons.hotel;

  @override
  String get cardTitle => 'Hotel: $hotelName';

  @override
  List<SmartAction> get actions {
    final list = [
      const SmartAction(
        type: SmartActionType.openBooking,
        label: 'Open Booking',
        icon: Icons.book_online,
      ),
    ];
    if (address != null && address!.isNotEmpty) {
      list.add(const SmartAction(
        type: SmartActionType.navigate,
        label: 'Get Directions',
        icon: Icons.directions,
      ));
    }
    list.add(const SmartAction(
      type: SmartActionType.copy,
      label: 'Copy Booking ID',
      icon: Icons.copy,
    ));
    return list;
  }

  factory HotelEntity.fromJson(Map<String, dynamic> json) {
    return HotelEntity(
      hotelName: json['hotelName'] as String? ?? 'Hotel',
      bookingId: json['bookingId'] as String? ?? json['value'] as String? ?? '',
      address: json['address'] as String?,
      checkInDate: json['checkInDate'] != null ? DateTime.tryParse(json['checkInDate'] as String) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'hotelName': hotelName,
        'bookingId': bookingId,
        'address': address,
        'checkInDate': checkInDate?.toIso8601String(),
      };
}
