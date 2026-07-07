import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/itinerary.dart';
import '../models/stop.dart';
import '../models/transit_mode.dart';
import '../models/vehicle.dart';
import '../services/location_service.dart';
import '../state/transit_state.dart';
import '../utils/color_utils.dart';
import '../utils/geo.dart';
import '../widgets/departures_sheet.dart';
import '../widgets/destination_search_delegate.dart';
import '../widgets/nearby_panel.dart';
import '../widgets/trip_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Timer? _vehicleAnimationTimer;
  bool _mapReady = false;
  bool _initialCenterDone = false;
  Itinerary? _fittedItinerary;
  bool _followUser = false;
  bool _wasNavigating = false;
  LatLng? _lastFollowPoint;
  static const Distance _distance = Distance();

  @override
  void initState() {
    super.initState();
    // Retrace les véhicules chaque seconde pour un déplacement fluide
    // entre deux rafraîchissements de l'API.
    _vehicleAnimationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        final state = context.read<TransitState>();
        // Ne redessine que si des véhicules sont réellement affichés.
        if (state.vehicles.isNotEmpty && !state.hasTrip) {
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

  void _onMapReady() {
    _mapReady = true;
    final position = context.read<TransitState>().userPosition;
    if (position != null) {
      _initialCenterDone = true;
      _centerOnUser(position);
    }
    _notifyMapMoved();
  }

  void _notifyMapMoved() {
    if (!_mapReady) return;
    try {
      final camera = _mapController.camera;
      final bounds = camera.visibleBounds;
      context.read<TransitState>().onMapMoved(
            bounds.southWest,
            bounds.northEast,
            camera.zoom,
          );
    } catch (_) {
      // La caméra n'est pas encore disponible : on ignore silencieusement.
    }
  }

  void _recenter() {
    final state = context.read<TransitState>();
    final position = state.userPosition ?? LocationService.fallback;
    _followUser = true;
    _centerOnUser(position);
    state.refreshUserPosition();
  }

  /// Centre la carte sur [target] en le décalant vers le haut pour qu'il reste
  /// visible au-dessus du panneau inférieur. Robuste si la carte n'est pas prête.
  void _centerOnUser(LatLng target, {double? zoom, double topFraction = 0.24}) {
    if (!_mapReady) return;
    try {
      final z = zoom ?? _mapController.camera.zoom;
      _mapController.move(target, z);
      final bounds = _mapController.camera.visibleBounds;
      final latSpan = (bounds.north - bounds.south).abs();
      final biasedLat = target.latitude - (0.5 - topFraction) * latSpan;
      _mapController.move(LatLng(biasedLat, target.longitude), z);
    } catch (_) {
      // En cas d'échec on tente un simple centrage.
      try {
        _mapController.move(target, zoom ?? 16);
      } catch (_) {}
    }
  }

  Future<void> _openDestinationSearch() async {
    final state = context.read<TransitState>();
    final place = await showSearch(
      context: context,
      delegate: DestinationSearchDelegate(state),
    );
    if (place != null && mounted) {
      state.planTripTo(place.latLng, place.name);
    }
  }

  void _onNearbySelected(Stop stop) {
    final state = context.read<TransitState>();
    _followUser = false;
    if (_mapReady) {
      try {
        _mapController.move(LatLng(stop.lat, stop.lon), 17);
      } catch (_) {}
    }
    state.selectStop(stop);
  }

  void _fitToItinerary(Itinerary itinerary) {
    if (!_mapReady) return;
    final points = itinerary.geometry;
    if (points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.fromLTRB(50, 130, 50, 340),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransitState>();
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final userPosition = state.userPosition;

    // Centrage initial dès que la position est disponible et la carte prête.
    if (userPosition != null && !_initialCenterDone && _mapReady) {
      _initialCenterDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOnUser(userPosition);
      });
    }

    // Ajuste la caméra au nouvel itinéraire sélectionné.
    final itinerary = state.selectedItinerary;
    if (itinerary != null && itinerary != _fittedItinerary) {
      _fittedItinerary = itinerary;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToItinerary(itinerary);
      });
    } else if (itinerary == null) {
      _fittedItinerary = null;
    }

    // Suivi automatique de l'avancement pendant la navigation.
    if (state.navigating && !_wasNavigating) _followUser = true;
    _wasNavigating = state.navigating;
    if (state.navigating && _followUser) {
      final target = state.progressPoint ?? state.userPosition;
      if (target != null &&
          (_lastFollowPoint == null ||
              _distance(_lastFollowPoint!, target) > 8)) {
        _lastFollowPoint = target;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _centerOnUser(target, topFraction: 0.4);
        });
      }
    }

    final inOverlayMode = state.hasTrip || state.selectedStop != null;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapView(state)),

          if (state.loadingStops || state.loadingNearby)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Bandeau de localisation indisponible.
          if (state.locationDenied)
            Positioned(
              top: media.padding.top + 8,
              left: 68,
              right: 68,
              child: _InfoBanner(
                icon: Icons.location_off,
                text: 'Localisation indisponible',
                color: theme.colorScheme.errorContainer,
                textColor: theme.colorScheme.onErrorContainer,
              ),
            ),

          // Bouton retour (mode itinéraire / détail d'arrêt).
          if (inOverlayMode)
            Positioned(
              top: media.padding.top + 8,
              left: 12,
              child: _RoundButton(
                icon: Icons.arrow_back,
                onTap: () {
                  _followUser = false;
                  if (state.hasTrip) {
                    state.clearTrip();
                  } else {
                    state.clearSelection();
                  }
                },
              ),
            ),

          // Bouton de recentrage, toujours visible en haut à droite.
          Positioned(
            top: media.padding.top + 8,
            right: 12,
            child: _RoundButton(
              icon: Icons.my_location,
              onTap: _recenter,
            ),
          ),

          _buildSheet(state, media),
        ],
      ),
    );
  }

  /// Feuille inférieure adaptative selon le mode courant.
  Widget _buildSheet(TransitState state, MediaQueryData media) {
    if (state.hasTrip) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.22,
        maxChildSize: 0.92,
        snap: true,
        builder: (context, controller) =>
            TripSheet(scrollController: controller),
      );
    }
    if (state.selectedStop != null) {
      return DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.2,
        maxChildSize: 0.9,
        snap: true,
        builder: (context, controller) =>
            DeparturesSheet(scrollController: controller),
      );
    }
    // Accueil : panneau « autour de moi » occupant ~60 % de l'écran.
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.32,
      maxChildSize: 0.92,
      snap: true,
      builder: (context, controller) => NearbyPanel(
        scrollController: controller,
        onSearchTap: _openDestinationSearch,
        onDepartureSelected: _onNearbySelected,
      ),
    );
  }

  Widget _buildMapView(TransitState state) {
    final userPosition = state.userPosition;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userPosition ?? LocationService.fallback,
        initialZoom: 16,
        minZoom: 3,
        maxZoom: 19,
        onMapReady: _onMapReady,
        onMapEvent: (event) {
          // Toute interaction manuelle désactive le suivi automatique.
          if (event.source != MapEventSource.mapController &&
              (event is MapEventMove ||
                  event is MapEventMoveStart ||
                  event is MapEventFlingAnimationStart ||
                  event is MapEventDoubleTapZoomStart ||
                  event is MapEventScrollWheelZoom)) {
            _followUser = false;
          }
          if (event is MapEventMoveEnd ||
              event is MapEventFlingAnimationEnd ||
              event is MapEventDoubleTapZoomEnd ||
              event is MapEventScrollWheelZoom) {
            _notifyMapMoved();
          }
        },
        onTap: (_, _) {
          if (state.selectedStop != null) state.clearSelection();
        },
        onLongPress: (_, latlng) =>
            state.planTripTo(latlng, 'Point sur la carte'),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.transitproche.transit_proche',
          maxZoom: 19,
        ),
        if (state.selectedItinerary != null)
          PolylineLayer(polylines: _tripPolylines(state)),
        MarkerLayer(markers: _stopMarkers(state)),
        if (!state.hasTrip) MarkerLayer(markers: _vehicleMarkers(state)),
        if (state.hasTrip) MarkerLayer(markers: _tripMarkers(state)),
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
          attributions: const [
            TextSourceAttribution('© OpenStreetMap'),
            TextSourceAttribution('Données : Transitous / MOTIS'),
          ],
        ),
      ],
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

  List<Polyline> _tripPolylines(TransitState state) {
    final itinerary = state.selectedItinerary;
    if (itinerary == null) return const [];
    final lines = <Polyline>[];

    for (final leg in itinerary.legs) {
      if (leg.geometry.length < 2) continue;
      if (leg.isWalk) {
        lines.add(Polyline(
          points: leg.geometry,
          color: Colors.blueGrey.shade600,
          strokeWidth: 4,
          pattern: StrokePattern.dotted(),
        ));
      } else {
        final mode = TransitMode.fromApi(leg.mode);
        final color = hexColor(leg.routeColor, mode.color);
        lines.add(Polyline(
          points: leg.geometry,
          color: color,
          strokeWidth: 6,
          borderColor: Colors.white,
          borderStrokeWidth: 2,
        ));
      }
    }

    // Portion déjà parcourue, grisée, pendant la navigation.
    if (state.navigating) {
      final full = itinerary.geometry;
      final total = polylineLength(full);
      if (total > 0) {
        final travelled =
            splitPolyline(full, total * state.tripProgress).travelled;
        if (travelled.length >= 2) {
          lines.add(Polyline(
            points: travelled,
            color: Colors.grey.withValues(alpha: 0.7),
            strokeWidth: 6,
          ));
        }
      }
    }
    return lines;
  }

  List<Marker> _tripMarkers(TransitState state) {
    final markers = <Marker>[];
    final destination = state.destination;
    if (destination != null) {
      markers.add(Marker(
        point: destination,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 40),
      ));
    }
    if (state.navigating) {
      final progress = state.progressPoint;
      if (progress != null) {
        markers.add(Marker(
          point: progress,
          width: 24,
          height: 24,
          child: const _ProgressMarker(),
        ));
      }
    }
    return markers;
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
    final color = hexColor(vehicle.routeColor, mode.color);
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

class _ProgressMarker extends StatelessWidget {
  const _ProgressMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF00C853),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: theme.colorScheme.surface,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: theme.colorScheme.onSurface),
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
