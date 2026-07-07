import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/stop.dart';
import '../models/transit_mode.dart';
import '../models/vehicle.dart';
import '../services/location_service.dart';
import '../state/transit_state.dart';
import '../widgets/departures_sheet.dart';
import '../widgets/stop_search_delegate.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _vehicleAnimationTimer;
  bool _initialCenterDone = false;

  @override
  void initState() {
    super.initState();
    // Retrace les véhicules chaque seconde pour un déplacement fluide
    // entre deux rafraîchissements de l'API.
    _vehicleAnimationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted && context.read<TransitState>().vehicles.isNotEmpty) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _vehicleAnimationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _notifyMapMoved() {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    context.read<TransitState>().onMapMoved(
          bounds.southWest,
          bounds.northEast,
          camera.zoom,
        );
  }

  void _recenter() {
    final state = context.read<TransitState>();
    final position = state.userPosition ?? LocationService.fallback;
    _mapController.move(position, 16);
    state.refreshUserPosition();
  }

  Future<void> _openSearch() async {
    final state = context.read<TransitState>();
    final stop = await showSearch<Stop?>(
      context: context,
      delegate: StopSearchDelegate(state),
    );
    if (stop != null && mounted) {
      _mapController.move(LatLng(stop.lat, stop.lon), 17);
      state.selectStop(stop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransitState>();
    final theme = Theme.of(context);
    final userPosition = state.userPosition;

    if (userPosition != null && !_initialCenterDone) {
      _initialCenterDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userPosition, 16);
        _notifyMapMoved();
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userPosition ?? LocationService.fallback,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd ||
                    event is MapEventDoubleTapZoomEnd ||
                    event is MapEventScrollWheelZoom) {
                  _notifyMapMoved();
                }
              },
              onTap: (_, _) => state.clearSelection(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.transitproche.transit_proche',
                maxZoom: 19,
              ),
              MarkerLayer(markers: _stopMarkers(state)),
              MarkerLayer(markers: _vehicleMarkers(state)),
              if (userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: userPosition,
                      width: 26,
                      height: 26,
                      child: const _UserLocationMarker(),
                    ),
                  ],
                ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap'),
                  TextSourceAttribution('Données : Transitous / MOTIS'),
                ],
              ),
            ],
          ),

          // Barre supérieure : recherche + statut.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  _SearchBar(onTap: _openSearch),
                  if (state.locationDenied)
                    _InfoBanner(
                      icon: Icons.location_off,
                      text:
                          'Localisation indisponible : position par défaut affichée.',
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                  if (state.zoomedTooFarOut)
                    _InfoBanner(
                      icon: Icons.zoom_in,
                      text: 'Zoomez pour afficher les arrêts proches.',
                      color: theme.colorScheme.secondaryContainer,
                      textColor: theme.colorScheme.onSecondaryContainer,
                    ),
                  if (state.error != null)
                    _InfoBanner(
                      icon: Icons.cloud_off,
                      text: 'Problème réseau : ${state.error}',
                      color: theme.colorScheme.errorContainer,
                      textColor: theme.colorScheme.onErrorContainer,
                    ),
                ],
              ),
            ),
          ),

          if (state.loadingStops)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),

          // Feuille des départs.
          if (state.selectedStop != null)
            DraggableScrollableSheet(
              initialChildSize: 0.42,
              minChildSize: 0.18,
              maxChildSize: 0.85,
              builder: (context, scrollController) =>
                  DeparturesSheet(scrollController: scrollController),
            ),
        ],
      ),
      floatingActionButton: state.selectedStop == null
          ? FloatingActionButton(
              onPressed: _recenter,
              tooltip: 'Recentrer sur ma position',
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  List<Marker> _stopMarkers(TransitState state) {
    return state.stops.map((stop) {
      final mainMode = stop.modes.isNotEmpty
          ? TransitMode.fromApi(stop.modes.first)
          : TransitMode.other;
      final isSelected = state.selectedStop?.stopId == stop.stopId;
      final size = isSelected ? 40.0 : 30.0;
      return Marker(
        point: LatLng(stop.lat, stop.lon),
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () => context.read<TransitState>().selectStop(stop),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: mainMode.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              mainMode.icon,
              color: Colors.white,
              size: size * 0.6,
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _vehicleMarkers(TransitState state) {
    final now = DateTime.now().toUtc();
    final markers = <Marker>[];
    for (final vehicle in state.vehicles) {
      final position = vehicle.positionAt(now);
      if (position == null) continue;
      markers.add(
        Marker(
          point: position,
          width: 34,
          height: 22,
          child: _VehicleChip(vehicle: vehicle),
        ),
      );
    }
    return markers;
  }
}

class _VehicleChip extends StatelessWidget {
  final Vehicle vehicle;

  const _VehicleChip({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final mode = TransitMode.fromApi(vehicle.mode);
    final color = vehicle.routeColor != null
        ? Color(int.parse('FF${vehicle.routeColor}', radix: 16))
        : mode.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: vehicle.realTime ? Colors.white : Colors.white70,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          vehicle.routeShortName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                'Rechercher un arrêt, une gare…',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
