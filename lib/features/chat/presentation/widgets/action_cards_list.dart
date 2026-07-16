import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_reply_app/features/chat/data/models/address_entity.dart';
import 'package:smart_reply_app/features/chat/domain/entities/chat_entity.dart';
import 'package:smart_reply_app/features/chat/presentation/bloc/smart_action_bloc.dart';

class ActionCardsList extends StatelessWidget {
  final List<ChatEntity> entities;

  const ActionCardsList({
    super.key,
    required this.entities,
  });

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) return const SizedBox.shrink();

    final hasMap = entities.any((e) => e is AddressEntity);
    final height = hasMap ? 130.0 : 48.0;

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: entities.length,
        itemBuilder: (context, index) {
          final entity = entities[index];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entity is AddressEntity)
                AnimatedActionCard(
                  child: MapPreviewCard(addressEntity: entity),
                )
              else
                ...entity.actions.map(
                  (action) => AnimatedActionCard(
                    child: StandardActionCard(entity: entity, action: action),
                  ),
                ),
              const SizedBox(width: 4),
            ],
          );
        },
      ),
    );
  }
}

// --- Micro-animation Wrapper ---
class AnimatedActionCard extends StatefulWidget {
  final Widget child;
  const AnimatedActionCard({super.key, required this.child});

  @override
  State<AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<AnimatedActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.25, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

// --- Standard Action Card UI ---
class StandardActionCard extends StatelessWidget {
  final ChatEntity entity;
  final SmartAction action;

  const StandardActionCard({
    super.key,
    required this.entity,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            context.read<SmartActionBloc>().add(
                  ExecuteActionEvent(entity: entity, action: action),
                );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  action.icon,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Mini Map Card UI for Addresses ---
class MapPreviewCard extends StatefulWidget {
  final AddressEntity addressEntity;

  const MapPreviewCard({
    super.key,
    required this.addressEntity,
  });

  @override
  State<MapPreviewCard> createState() => _MapPreviewCardState();
}

class _MapPreviewCardState extends State<MapPreviewCard> {
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
      debugPrint('[MapPreviewCard] Geocoding failed: $e');
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
      width: 240,
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (lat != null && lng != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(lat, lng),
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('location'),
                    position: LatLng(lat, lng),
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                compassEnabled: false,
                liteModeEnabled: true,
              )
            else
              Center(
                child: _geocoding
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.map, size: 36, color: colorScheme.outline),
              ),
            // Floating overlay for directions & maps trigger
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    final resolvedEntity = AddressEntity(
                      address: widget.addressEntity.address,
                      latitude: lat,
                      longitude: lng,
                    );
                    context.read<SmartActionBloc>().add(
                          ExecuteActionEvent(
                            entity: resolvedEntity,
                            action: const SmartAction(
                              type: SmartActionType.navigate,
                              label: 'Directions',
                              icon: Icons.navigation,
                            ),
                          ),
                        );
                  },
                  child: Row(
                    children: [
                      Icon(Icons.directions, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.addressEntity.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
