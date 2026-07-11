import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/departure.dart';
import '../models/itinerary.dart';
import '../models/place_suggestion.dart';
import '../models/stop.dart';
import '../models/vehicle.dart';
import '../services/location_service.dart';
import '../services/transitous_api.dart';
import '../utils/geo.dart';

/// État global de l'application : position de l'utilisateur, arrêts et
/// véhicules visibles, départs de l'arrêt sélectionné. Rafraîchit les
/// véhicules toutes les 15 s et les départs toutes les 30 s.
class TransitState extends ChangeNotifier {
  TransitState({TransitousApi? api, LocationService? locationService})
      : _api = api ?? TransitousApi(),
        _location = locationService ?? LocationService();

  final TransitousApi _api;
  final LocationService _location;

  static const Duration _vehicleRefresh = Duration(seconds: 15);
  static const Duration _departureRefresh = Duration(seconds: 30);
  static const Duration _nearbyRefresh = Duration(seconds: 30);
  static const double _maxStopZoomOut = 13.5;

  /// Fenêtre de temps maximale des départs affichés « autour de moi ».
  static const int nearbyMaxMinutes = 20;
  static const Distance _distance = Distance();

  LatLng? userPosition;
  bool locationDenied = false;

  List<Stop> stops = [];
  List<Vehicle> vehicles = [];

  Stop? selectedStop;
  List<Departure> departures = [];
  bool loadingDepartures = false;

  bool loadingStops = false;
  String? error;

  // --- Départs autour de moi ---
  List<NearbyDeparture> nearbyDepartures = [];
  bool loadingNearby = false;
  Timer? _nearbyTimer;
  int _nearbyRequestId = 0;
  bool _nearbyInFlight = false;

  // --- Itinéraire / navigation ---
  LatLng? destination;
  String? destinationName;
  List<Itinerary> itineraries = [];
  Itinerary? selectedItinerary;
  bool planning = false;
  String? planError;
  bool navigating = false;
  Timer? _navTimer;

  LatLng? _viewSouthWest;
  LatLng? _viewNorthEast;
  double _viewZoom = 16;

  Timer? _vehicleTimer;
  Timer? _departureTimer;
  Timer? _mapMoveDebounce;
  StreamSubscription<LatLng>? _positionSub;
  int _stopsRequestId = 0;
  int _departuresRequestId = 0;

  bool get zoomedTooFarOut => _viewZoom < _maxStopZoomOut;

  Future<void> init() async {
    final position = await _location.currentPosition();
    if (position == null) {
      locationDenied = true;
      userPosition = LocationService.fallback;
    } else {
      userPosition = position;
      _positionSub = _location.positionStream().listen((p) {
        userPosition = p;
        notifyListeners();
      }, onError: (_) {});
    }
    notifyListeners();

    _vehicleTimer = Timer.periodic(_vehicleRefresh, (_) => _refreshVehicles());
    _nearbyTimer = Timer.periodic(_nearbyRefresh, (_) => refreshNearby());
    refreshNearby();
  }

  /// Charge les prochains départs des arrêts les plus proches (≤ 20 min),
  /// tous modes confondus, triés par heure. Rafraîchi en temps réel.
  Future<void> refreshNearby() async {
    final pos = userPosition;
    if (pos == null) return;
    // Évite les exécutions concurrentes (timer + déclenchements manuels).
    if (_nearbyInFlight) return;
    _nearbyInFlight = true;

    final requestId = ++_nearbyRequestId;
    loadingNearby = true;
    notifyListeners();

    try {
      // Zone d'environ 600 m autour de l'utilisateur. On borne le cosinus
      // pour éviter une division par ~0 près des pôles.
      const dLat = 0.006;
      final cosLat = math.cos(pos.latitude * math.pi / 180).abs();
      final dLon = 0.006 / (cosLat < 0.01 ? 0.01 : cosLat);
      final sw = LatLng(pos.latitude - dLat, pos.longitude - dLon);
      final ne = LatLng(pos.latitude + dLat, pos.longitude + dLon);

      final stops = await _api.stopsInArea(sw, ne);
      if (requestId != _nearbyRequestId) return;

      stops.sort((a, b) => _distance(pos, LatLng(a.lat, a.lon))
          .compareTo(_distance(pos, LatLng(b.lat, b.lon))));
      final nearest = stops.take(8).toList();

      final lists = await Future.wait(nearest.map((stop) async {
        try {
          final deps = await _api.departures(stop.stopId, count: 8);
          final dist = _distance(pos, LatLng(stop.lat, stop.lon)).toDouble();
          return deps
              .map((d) => NearbyDeparture(
                    departure: d,
                    stop: stop,
                    distanceMeters: dist,
                  ))
              .toList();
        } on Exception {
          return <NearbyDeparture>[];
        }
      }));
      if (requestId != _nearbyRequestId) return;

      final now = DateTime.now();
      final merged = <NearbyDeparture>[];
      for (final list in lists) {
        merged.addAll(list);
      }
      nearbyDepartures = merged.where((n) {
        final minutes = n.departure.minutesUntil(now);
        return !n.departure.cancelled &&
            minutes >= 0 &&
            minutes <= nearbyMaxMinutes;
      }).toList()
        ..sort((a, b) => a.departure.departure.compareTo(b.departure.departure));
      error = null;
    } on Exception catch (e) {
      if (requestId == _nearbyRequestId) error = e.toString();
    } finally {
      _nearbyInFlight = false;
      if (requestId == _nearbyRequestId) {
        loadingNearby = false;
        notifyListeners();
      }
    }
  }

  /// Appelé par la carte quand la zone visible change.
  void onMapMoved(LatLng southWest, LatLng northEast, double zoom) {
    _viewSouthWest = southWest;
    _viewNorthEast = northEast;
    _viewZoom = zoom;

    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 450), () {
      _refreshStops();
      _refreshVehicles();
    });
  }

  Future<void> _refreshStops() async {
    final sw = _viewSouthWest;
    final ne = _viewNorthEast;
    if (sw == null || ne == null) return;

    if (zoomedTooFarOut) {
      stops = [];
      notifyListeners();
      return;
    }

    final requestId = ++_stopsRequestId;
    loadingStops = true;
    notifyListeners();
    try {
      final result = await _api.stopsInArea(sw, ne);
      if (requestId != _stopsRequestId) return;
      stops = result;
      error = null;
    } on Exception catch (e) {
      if (requestId != _stopsRequestId) return;
      error = e.toString();
    } finally {
      if (requestId == _stopsRequestId) {
        loadingStops = false;
        notifyListeners();
      }
    }
  }

  Future<void> _refreshVehicles() async {
    final sw = _viewSouthWest;
    final ne = _viewNorthEast;
    if (sw == null || ne == null || zoomedTooFarOut) {
      if (vehicles.isNotEmpty) {
        vehicles = [];
        notifyListeners();
      }
      return;
    }
    try {
      final result =
          await _api.vehiclesInArea(sw, ne, zoom: _viewZoom.round());
      vehicles = result;
      notifyListeners();
    } on Exception {
      // Les véhicules sont un bonus visuel : on garde silencieusement
      // les dernières positions connues en cas d'erreur réseau ponctuelle.
    }
  }

  Future<void> selectStop(Stop stop) async {
    selectedStop = stop;
    departures = [];
    loadingDepartures = true;
    notifyListeners();

    _departureTimer?.cancel();
    _departureTimer =
        Timer.periodic(_departureRefresh, (_) => _loadDepartures());
    await _loadDepartures();
  }

  Future<void> _loadDepartures() async {
    final stop = selectedStop;
    if (stop == null) return;
    final requestId = ++_departuresRequestId;
    try {
      final result = await _api.departures(stop.stopId);
      if (requestId != _departuresRequestId || selectedStop?.stopId != stop.stopId) {
        return;
      }
      final now = DateTime.now();
      departures = result
          .where((d) => d.departure.isAfter(
              now.subtract(const Duration(minutes: 1))))
          .toList()
        ..sort((a, b) => a.departure.compareTo(b.departure));
      error = null;
    } on Exception catch (e) {
      if (requestId != _departuresRequestId) return;
      error = e.toString();
    } finally {
      if (requestId == _departuresRequestId) {
        loadingDepartures = false;
        notifyListeners();
      }
    }
  }

  void clearSelection() {
    selectedStop = null;
    departures = [];
    _departureTimer?.cancel();
    _departureTimer = null;
    notifyListeners();
  }

  Future<List<Stop>> searchStops(String query) {
    return _api.geocodeStops(query, near: userPosition);
  }

  /// Recherche de destination (adresses, lieux et arrêts).
  Future<List<PlaceSuggestion>> searchPlaces(String query) {
    return _api.geocodePlaces(query, near: userPosition);
  }

  // --- Planification et suivi d'itinéraire ---

  bool get hasTrip => destination != null;

  /// Calcule des itinéraires depuis la position actuelle vers [dest].
  Future<void> planTripTo(LatLng dest, String name) async {
    clearSelection();
    destination = dest;
    destinationName = name;
    selectedItinerary = null;
    itineraries = [];
    navigating = false;
    planError = null;
    planning = true;
    notifyListeners();

    final origin = userPosition ?? LocationService.fallback;
    try {
      final results = await _api.planTrip(from: origin, to: dest);
      itineraries = results;
      selectedItinerary = results.isNotEmpty ? results.first : null;
      planError = results.isEmpty ? 'Aucun itinéraire trouvé.' : null;
    } on Exception catch (e) {
      planError = e.toString();
    } finally {
      planning = false;
      notifyListeners();
    }
  }

  void selectItinerary(Itinerary itinerary) {
    selectedItinerary = itinerary;
    navigating = false;
    notifyListeners();
  }

  void startNavigation() {
    if (selectedItinerary == null) return;
    navigating = true;
    _navTimer?.cancel();
    // Rafraîchit le décompte du temps restant régulièrement.
    _navTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (navigating) notifyListeners();
    });
    notifyListeners();
  }

  void stopNavigation() {
    navigating = false;
    _navTimer?.cancel();
    _navTimer = null;
    notifyListeners();
  }

  void clearTrip() {
    destination = null;
    destinationName = null;
    itineraries = [];
    selectedItinerary = null;
    planning = false;
    planError = null;
    navigating = false;
    _navTimer?.cancel();
    _navTimer = null;
    notifyListeners();
  }

  /// Distance (m) parcourue le long de l'itinéraire sélectionné, selon la
  /// position actuelle projetée sur le tracé.
  SnapResult? get _progress {
    final itinerary = selectedItinerary;
    final pos = userPosition;
    if (itinerary == null || pos == null) return null;
    final geometry = itinerary.geometry;
    if (geometry.length < 2) return null;
    return snapToPolyline(geometry, pos);
  }

  /// Avancement sur l'itinéraire, entre 0 et 1.
  double get tripProgress {
    final itinerary = selectedItinerary;
    final snap = _progress;
    if (itinerary == null || snap == null) return 0;
    final total = polylineLength(itinerary.geometry);
    if (total <= 0) return 0;
    return (snap.distanceAlong / total).clamp(0.0, 1.0);
  }

  /// Position projetée de l'utilisateur sur le tracé (marqueur d'avancement).
  LatLng? get progressPoint => _progress?.point;

  /// Temps restant estimé avant l'arrivée (décroît au fil du trajet).
  Duration? get remainingDuration {
    final itinerary = selectedItinerary;
    if (itinerary == null) return null;
    final byClock = itinerary.endTime.difference(DateTime.now());
    if (!navigating) {
      return byClock.isNegative ? Duration.zero : byClock;
    }
    // En navigation, on combine l'horaire prévu et l'avancement réel sur le
    // tracé pour un décompte cohérent même hors ligne temporelle.
    final remainingByProgress = Duration(
      seconds: (itinerary.durationSeconds * (1 - tripProgress)).round(),
    );
    final chosen = byClock.isNegative ? remainingByProgress : byClock;
    return chosen.isNegative ? Duration.zero : chosen;
  }

  /// Distance restante estimée (m) le long de l'itinéraire.
  double? get remainingDistance {
    final itinerary = selectedItinerary;
    final snap = _progress;
    if (itinerary == null || snap == null) return null;
    final total = polylineLength(itinerary.geometry);
    return (total - snap.distanceAlong).clamp(0.0, total);
  }

  /// Le leg en cours de parcours, d'après l'avancement.
  TripLeg? get currentLeg {
    final itinerary = selectedItinerary;
    final snap = _progress;
    if (itinerary == null) return null;
    if (snap == null) {
      return itinerary.legs.isNotEmpty ? itinerary.legs.first : null;
    }
    var accumulated = 0.0;
    for (final leg in itinerary.legs) {
      final length = polylineLength(leg.geometry);
      if (snap.distanceAlong <= accumulated + length || leg == itinerary.legs.last) {
        return leg;
      }
      accumulated += length;
    }
    return itinerary.legs.isNotEmpty ? itinerary.legs.last : null;
  }

  Future<void> refreshUserPosition() async {
    final position = await _location.currentPosition();
    if (position != null) {
      userPosition = position;
      locationDenied = false;
      notifyListeners();
      refreshNearby();
    }
  }

  @override
  void dispose() {
    _vehicleTimer?.cancel();
    _departureTimer?.cancel();
    _mapMoveDebounce?.cancel();
    _navTimer?.cancel();
    _nearbyTimer?.cancel();
    _positionSub?.cancel();
    _api.dispose();
    super.dispose();
  }
}
