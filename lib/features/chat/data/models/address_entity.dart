import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class AddressEntity implements ChatEntity {
  final String address;
  final double? latitude;
  final double? longitude;

  AddressEntity({
    required this.address,
    this.latitude,
    this.longitude,
  });

  @override
  String get type => 'address';

  @override
  IconData get icon => Icons.location_on;

  @override
  String get cardTitle => address;

  @override
  List<SmartAction> get actions {
    final list = <SmartAction>[];
    
    // Always support maps opening
    list.add(const SmartAction(
      type: SmartActionType.openGoogleMaps,
      label: 'Open Google Maps',
      icon: Icons.map,
    ));
    list.add(const SmartAction(
      type: SmartActionType.openAppleMaps,
      label: 'Open Apple Maps',
      icon: Icons.pin_drop,
    ));
    
    if (latitude != null && longitude != null) {
      list.add(const SmartAction(
        type: SmartActionType.navigate,
        label: 'Navigate',
        icon: Icons.navigation,
      ));
    }
    
    list.add(const SmartAction(
      type: SmartActionType.copyAddress,
      label: 'Copy Address',
      icon: Icons.copy,
    ));
    list.add(const SmartAction(
      type: SmartActionType.share,
      label: 'Share',
      icon: Icons.share,
    ));
    
    return list;
  }

  factory AddressEntity.fromJson(Map<String, dynamic> json) {
    return AddressEntity(
      address: json['address'] as String? ?? json['value'] as String? ?? 'Address',
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}
