import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_message.dart';
import 'package:smart_reply_app/core/enums/message_status.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/smart_action_bloc.dart';

// Concrete entity models
import 'package:smart_reply_app/features/chat/data/models/address_entity.dart';
import 'package:smart_reply_app/features/chat/data/models/meeting_entity.dart';
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

class EntityUiMeta {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget? preview;
  final List<SmartAction> actions;

  EntityUiMeta({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.preview,
    required this.actions,
  });
}

class SmartEntityBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatEntity entity;
  final bool isMine;
  final VoidCallback? onReplyTapped;

  const SmartEntityBubble({
    super.key,
    required this.message,
    required this.entity,
    required this.isMine,
    this.onReplyTapped,
  });

  // WhatsApp style teal color
  static const Color whatsappTeal = Color(0xFF008069);

  EntityUiMeta _resolveMeta(ChatEntity entity) {
    if (entity is AddressEntity) {
      return EntityUiMeta(
        icon: Icons.location_on,
        iconBgColor: const Color(0xFFE8F5E9), // Softer green tint
        title: "Address",
        subtitle: "Physical location details",
        preview: AddressMapPreview(addressEntity: entity),
        actions: const [
          SmartAction(type: SmartActionType.navigate, label: "Open Maps", icon: Icons.map),
          SmartAction(type: SmartActionType.navigate, label: "Directions", icon: Icons.directions),
          SmartAction(type: SmartActionType.copy, label: "Copy", icon: Icons.copy),
          SmartAction(type: SmartActionType.share, label: "Share", icon: Icons.share),
        ],
      );
    } else if (entity is MeetingEntity) {
      return EntityUiMeta(
        icon: Icons.calendar_today,
        iconBgColor: const Color(0xFFFFF3E0), // Softer orange tint
        title: "Meeting scheduled",
        subtitle: "Calendar appointment",
        actions: entity.actions,
      );
    } else if (entity is PhoneEntity) {
      return EntityUiMeta(
        icon: Icons.phone,
        iconBgColor: const Color(0xFFE0F2F1), // Softer teal tint
        title: "Phone Number",
        subtitle: "Tap to call or message",
        actions: const [
          SmartAction(type: SmartActionType.call, label: "Call", icon: Icons.call),
          SmartAction(type: SmartActionType.whatsapp, label: "WhatsApp", icon: Icons.message),
          SmartAction(type: SmartActionType.copy, label: "Copy", icon: Icons.copy),
        ],
      );
    } else if (entity is EmailEntity) {
      return EntityUiMeta(
        icon: Icons.email,
        iconBgColor: const Color(0xFFE1F5FE), // Softer blue tint
        title: "Email Address",
        subtitle: "Send direct email",
        actions: const [
          SmartAction(type: SmartActionType.composeEmail, label: "Compose", icon: Icons.alternate_email),
          SmartAction(type: SmartActionType.copy, label: "Copy", icon: Icons.copy),
        ],
      );
    } else if (entity is UrlEntity) {
      final isMeet = entity.platform != null && entity.platform != "Website";
      return EntityUiMeta(
        icon: isMeet ? Icons.video_call : Icons.language,
        iconBgColor: isMeet ? const Color(0xFFFFEBEE) : const Color(0xFFE8EAF6), // Softer red/indigo tint
        title: isMeet ? "${entity.platform}" : "Website Link",
        subtitle: isMeet ? "Video meeting link" : "Web address",
        preview: isMeet ? const VideoMeetingMockPreview() : WebLinkMockPreview(url: entity.url),
        actions: isMeet
            ? const [
                SmartAction(type: SmartActionType.joinMeeting, label: "Join Meeting", icon: Icons.video_call),
                SmartAction(type: SmartActionType.addToCalendar, label: "Add Calendar", icon: Icons.calendar_today),
                SmartAction(type: SmartActionType.setReminder, label: "Reminder", icon: Icons.alarm),
              ]
            : const [
                SmartAction(type: SmartActionType.openBrowser, label: "Open Link", icon: Icons.open_in_browser),
                SmartAction(type: SmartActionType.copy, label: "Copy Link", icon: Icons.copy),
                SmartAction(type: SmartActionType.share, label: "Share", icon: Icons.share),
              ],
      );
    } else if (entity is TaskEntity) {
      return EntityUiMeta(
        icon: Icons.check_circle_outline,
        iconBgColor: const Color(0xFFF3E5F5), // Softer purple tint
        title: "Action Item",
        subtitle: entity.listType == "shopping" ? "Shopping item list" : "Todo task",
        actions: entity.actions,
      );
    } else if (entity is ReminderEntity) {
      return EntityUiMeta(
        icon: Icons.alarm,
        iconBgColor: const Color(0xFFFBE9E7), // Softer orange-red tint
        title: "Reminder",
        subtitle: "Notification reminder",
        actions: entity.actions,
      );
    } else if (entity is PaymentEntity) {
      return EntityUiMeta(
        icon: Icons.payment,
        iconBgColor: const Color(0xFFE8F5E9),
        title: "Payment Request",
        subtitle: "Digital invoice",
        actions: entity.actions,
      );
    } else if (entity is ExpenseEntity) {
      return EntityUiMeta(
        icon: Icons.account_balance_wallet,
        iconBgColor: const Color(0xFFFCE4EC),
        title: "Expense Logged",
        subtitle: "Personal finance tracking",
        actions: entity.actions,
      );
    } else if (entity is FlightEntity) {
      return EntityUiMeta(
        icon: Icons.flight,
        iconBgColor: const Color(0xFFE0F7FA),
        title: "Flight Information",
        subtitle: "Travel plans",
        actions: entity.actions,
      );
    } else if (entity is HotelEntity) {
      return EntityUiMeta(
        icon: Icons.hotel,
        iconBgColor: const Color(0xFFFFF8E1),
        title: "Hotel Booking",
        subtitle: "Accommodation details",
        actions: entity.actions,
      );
    } else if (entity is OtpEntity) {
      return EntityUiMeta(
        icon: Icons.security,
        iconBgColor: const Color(0xFFFFEBEE),
        title: "Security Verification",
        subtitle: "One-Time Password (OTP)",
        actions: entity.actions,
      );
    } else if (entity is EventEntity) {
      return EntityUiMeta(
        icon: Icons.event,
        iconBgColor: const Color(0xFFEDE7F6),
        title: "Calendar Event",
        subtitle: "Scheduled event detail",
        actions: entity.actions,
      );
    } else {
      return EntityUiMeta(
        icon: Icons.star,
        iconBgColor: const Color(0xFFF5F5F5),
        title: "Information Card",
        subtitle: "Extracted details",
        actions: entity.actions,
      );
    }
  }

  Widget _buildContentWidget(BuildContext context, ChatEntity entity, ColorScheme colorScheme) {
    if (entity is AddressEntity) {
      return Text(
        entity.address,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface.withValues(alpha: 0.9),
          height: 1.3,
        ),
      );
    } else if (entity is MeetingEntity) {
      final dateStr = entity.date != null ? DateFormat.yMMMMd().format(entity.date!) : "";
      final timeStr = entity.time ?? "";
      final dateTime = "$dateStr${dateStr.isNotEmpty && timeStr.isNotEmpty ? " at " : ""}$timeStr";
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entity.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          if (dateTime.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dateTime,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (entity.url != null) ...[
            const SizedBox(height: 6),
            Text(
              entity.url!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ],
      );
    } else if (entity is UrlEntity) {
      return Text(
        entity.url,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
          height: 1.3,
        ),
      );
    } else if (entity is PhoneEntity) {
      return Text(
        entity.phoneNumber,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      );
    } else if (entity is EmailEntity) {
      return Text(
        entity.emailAddress,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      );
    } else if (entity is TaskEntity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entity.title,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface,
            ),
          ),
          if (entity.dueDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 10, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMMMd().add_jm().format(entity.dueDate!),
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      );
    } else if (entity is ReminderEntity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entity.title,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface,
            ),
          ),
          if (entity.dueDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.alarm, size: 10, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMMMd().add_jm().format(entity.dueDate!),
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ],
      );
    } else if (entity is PaymentEntity) {
      final recipientText = entity.recipient != null ? "\nRecipient: ${entity.recipient}" : "";
      return Text(
        "Amount: ${entity.currency}${entity.amount}$recipientText",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
        ),
      );
    } else if (entity is ExpenseEntity) {
      final categoryText = entity.category != null ? " on ${entity.category}" : "";
      return Text(
        "Spent: ${entity.currency}${entity.amount}$categoryText",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.red.shade700,
        ),
      );
    } else if (entity is FlightEntity) {
      final dateText = entity.date != null ? "\nDate: ${DateFormat.yMMMMd().format(entity.date!)}" : "";
      return Text(
        "Flight Number: ${entity.flightNumber}$dateText",
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
      );
    } else if (entity is HotelEntity) {
      return Text(
        entity.hotelName + (entity.checkInDate != null ? "\nCheck-in: ${entity.checkInDate}" : ""),
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
      );
    } else if (entity is OtpEntity) {
      return Text(
        "Your verification code: ${entity.otpCode}",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      );
    } else if (entity is EventEntity) {
      final timeText = entity.time != null ? " at ${entity.time}" : "";
      return Text(
        "Title: ${entity.title}\nDate: ${DateFormat.yMMMMd().format(entity.date)}$timeText",
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
      );
    } else {
      return Text(
        entity.type,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _resolveMeta(entity);
    final time = DateFormat.jm().format(message.createdAt);
    final colorScheme = Theme.of(context).colorScheme;

    final cardBgColor = isMine
        ? const Color(0xFFE7FFDB) // Premium WhatsApp soft green bubble
        : Colors.white;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message.isForwarded == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forward,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Forwarded',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            if (message.replyToText != null)
              GestureDetector(
                onTap: onReplyTapped,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.black12 : Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    message.replyToText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            // Header + Subtitle + Content Row (Side by side with preview)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: meta.iconBgColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                meta.icon,
                                size: 16,
                                color: whatsappTeal,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    meta.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    meta.subtitle,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Content details
                        _buildContentWidget(context, entity, colorScheme),
                      ],
                    ),
                  ),
                  if (meta.preview != null) ...[
                    const SizedBox(width: 12),
                    meta.preview!,
                  ],
                ],
              ),
            ),
            // Actions Divider
            const Divider(height: 1, thickness: 0.5),
            // Horizontal Action Bar (divided equally)
            if (meta.actions.isNotEmpty)
              IntrinsicHeight(
                child: Row(
                  children: List.generate(meta.actions.length, (index) {
                    final action = meta.actions[index];
                    return Expanded(
                      child: Row(
                        children: [
                          if (index > 0)
                            const VerticalDivider(
                              width: 1,
                              thickness: 0.5,
                              indent: 8,
                              endIndent: 8,
                            ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                context.read<SmartActionBloc>().add(
                                      ExecuteActionEvent(entity: entity, action: action),
                                    );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      action.icon,
                                      size: 13,
                                      color: whatsappTeal,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        action.label,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: whatsappTeal,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            // Divider before timestamp
            const Divider(height: 1, thickness: 0.5),
            // Timestamp and delivery status
            Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 6, top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    IconData iconData;
    Color color;

    switch (message.status) {
      case MessageStatus.sending:
        iconData = Icons.access_time;
        color = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
      case MessageStatus.sent:
      case MessageStatus.delivered:
        iconData = Icons.check;
        color = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
      case MessageStatus.read:
        iconData = Icons.done_all;
        color = Colors.blue;
      case MessageStatus.failed:
        iconData = Icons.error_outline;
        color = Theme.of(context).colorScheme.error;
    }

    return Icon(
      iconData,
      size: 14,
      color: color,
    );
  }
}

// --- Preview Sub-Widgets ---

class AddressMapPreview extends StatefulWidget {
  final AddressEntity addressEntity;
  const AddressMapPreview({super.key, required this.addressEntity});

  @override
  State<AddressMapPreview> createState() => _AddressMapPreviewState();
}

class _AddressMapPreviewState extends State<AddressMapPreview> {
  double? _latitude;
  double? _longitude;
  bool _geocoding = false;

  @override
  void initState() {
    super.initState();
    _latitude = widget.addressEntity.latitude;
    _longitude = widget.addressEntity.longitude;
    if (_latitude == null || _longitude == null) {
      _geocodeAddress();
    }
  }

  Future<void> _geocodeAddress() async {
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final locations = await geo.locationFromAddress(widget.addressEntity.address);
      if (locations.isNotEmpty && mounted) {
        setState(() {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
        });
      }
    } catch (e) {
      debugPrint('[AddressMapPreview] Geocoding failed: $e');
    } finally {
      if (mounted) {
        setState(() => _geocoding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lat = _latitude;
    final lng = _longitude;

    return Container(
      width: 110,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: lat != null && lng != null
            ? GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId("location"),
                    position: LatLng(lat, lng),
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                liteModeEnabled: true,
              )
            : Center(
                child: _geocoding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : Icon(Icons.map, size: 24, color: colorScheme.outline),
              ),
      ),
    );
  }
}

class VideoMeetingMockPreview extends StatelessWidget {
  const VideoMeetingMockPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 110,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildParticipant("KP", Colors.blueGrey),
                _buildParticipant("AM", Colors.teal),
                _buildParticipant("JD", Colors.orange),
                _buildParticipant("Me", Colors.indigo),
              ],
            ),
            Positioned(
              bottom: 2,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, size: 8, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam, size: 8, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, size: 8, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipant(String initials, Color color) {
    return Container(
      color: color.withValues(alpha: 0.8),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class WebLinkMockPreview extends StatelessWidget {
  final String url;
  const WebLinkMockPreview({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 110,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            height: 18,
            color: colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 8, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    url.replaceAll("https://", "").replaceAll("http://", ""),
                    style: TextStyle(fontSize: 8, color: colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Center(
                child: Icon(Icons.language, size: 28, color: colorScheme.primary.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
