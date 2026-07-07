import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/departure.dart';
import '../models/stop.dart';
import '../models/vehicle.dart';
import '../services/location_service.dart';
import '../services/transitous_api.dart';

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
  static const double _maxStopZoomOut = 13.5;

  LatLng? userPosition;
  bool locationDenied = false;

  List<Stop> stops = [];
  List<Vehicle> vehicles = [];

  Stop? selectedStop;
  List<Departure> departures = [];
  bool loadingDepartures = false;

  bool loadingStops = false;
  String? error;

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

  Future<void> refreshUserPosition() async {
    final position = await _location.currentPosition();
    if (position != null) {
      userPosition = position;
      locationDenied = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _vehicleTimer?.cancel();
    _departureTimer?.cancel();
    _mapMoveDebounce?.cancel();
    _positionSub?.cancel();
    _api.dispose();
    super.dispose();
  }
}
