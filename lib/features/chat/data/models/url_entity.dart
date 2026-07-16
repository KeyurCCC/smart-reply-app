import 'package:flutter/material.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';

class UrlEntity implements ChatEntity {
  final String url;
  final String? platform;

  UrlEntity({
    required this.url,
    this.platform,
  });

  @override
  String get type => 'url';

  @override
  IconData get icon {
    final lower = url.toLowerCase();
    if (lower.contains('meet.google.com') || platform == 'meet') {
      return Icons.videocam;
    } else if (lower.contains('zoom.us') || platform == 'zoom') {
      return Icons.video_call;
    } else if (lower.contains('teams.microsoft.com') || platform == 'teams') {
      return Icons.group;
    }
    return Icons.language;
  }

  @override
  String get cardTitle {
    final lower = url.toLowerCase();
    if (lower.contains('meet.google.com') || platform == 'meet') {
      return 'Google Meet Link';
    } else if (lower.contains('zoom.us') || platform == 'zoom') {
      return 'Zoom Meeting Link';
    } else if (lower.contains('teams.microsoft.com') || platform == 'teams') {
      return 'Microsoft Teams Link';
    }
    return url;
  }

  @override
  List<SmartAction> get actions {
    final lower = url.toLowerCase();
    final isMeeting = lower.contains('meet.google.com') ||
        lower.contains('zoom.us') ||
        lower.contains('teams.microsoft.com') ||
        platform == 'meet' ||
        platform == 'zoom' ||
        platform == 'teams';

    if (isMeeting) {
      final list = [
        const SmartAction(
          type: SmartActionType.joinMeeting,
          label: 'Join Meeting',
          icon: Icons.video_call,
        ),
      ];
      if (lower.contains('meet.google.com') || platform == 'meet') {
        list.add(const SmartAction(
          type: SmartActionType.addToCalendar,
          label: 'Add to Calendar',
          icon: Icons.calendar_today,
        ));
      }
      list.add(const SmartAction(
        type: SmartActionType.setReminder,
        label: 'Set Reminder',
        icon: Icons.alarm,
      ));
      list.add(const SmartAction(
        type: SmartActionType.copy,
        label: 'Copy Link',
        icon: Icons.copy,
      ));
      return list;
    }

    return [
      const SmartAction(
        type: SmartActionType.openBrowser,
        label: 'Open Browser',
        icon: Icons.open_in_browser,
      ),
      const SmartAction(
        type: SmartActionType.share,
        label: 'Share Link',
        icon: Icons.share,
      ),
      const SmartAction(
        type: SmartActionType.copy,
        label: 'Copy Link',
        icon: Icons.copy,
      ),
    ];
  }

  factory UrlEntity.fromJson(Map<String, dynamic> json) {
    return UrlEntity(
      url: json['url'] as String? ?? json['value'] as String? ?? '',
      platform: json['platform'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        'platform': platform,
      };
}
