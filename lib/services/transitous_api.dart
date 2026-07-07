import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/departure.dart';
import '../models/stop.dart';
import '../models/vehicle.dart';

/// Client pour l'API publique Transitous (https://transitous.org),
/// un service communautaire de routage de transports en commun basé sur
/// MOTIS, qui agrège les flux GTFS et GTFS-RT (temps réel) du monde entier.
class TransitousApi {
  static const String _baseUrl = 'api.transitous.org';
  static const Map<String, String> _headers = {
    // Identification demandée par la politique d'usage de Transitous.
    'User-Agent': 'TransitProche/1.0 (app Flutter open source)',
  };

  final http.Client _client;

  TransitousApi({http.Client? client}) : _client = client ?? http.Client();

  /// Arrêts dans la zone [southWest] – [northEast].
  Future<List<Stop>> stopsInArea(LatLng southWest, LatLng northEast) async {
    final uri = Uri.https(_baseUrl, '/api/v1/map/stops', {
      'min': '${southWest.latitude},${southWest.longitude}',
      'max': '${northEast.latitude},${northEast.longitude}',
    });
    final body = await _get(uri);
    final list = jsonDecode(body) as List<dynamic>;
    final stops =
        list.map((e) => Stop.fromJson(e as Map<String, dynamic>)).toList();

    // L'API renvoie chaque quai/zone d'embarquement : on regroupe par
    // station parente pour ne pas surcharger la carte.
    final byParent = <String, Stop>{};
    for (final stop in stops) {
      final existing = byParent[stop.stopId];
      if (existing == null) {
        byParent[stop.stopId] = stop;
      } else {
        final mergedModes = {...existing.modes, ...stop.modes}.toList();
        byParent[stop.stopId] = Stop(
          stopId: existing.stopId,
          name: existing.name,
          lat: existing.lat,
          lon: existing.lon,
          modes: mergedModes,
        );
      }
    }
    return byParent.values.toList();
  }

  /// Prochains départs à l'arrêt [stopId] (temps réel quand disponible).
  Future<List<Departure>> departures(String stopId, {int count = 25}) async {
    final uri = Uri.https(_baseUrl, '/api/v1/stoptimes', {
      'stopId': stopId,
      'n': '$count',
    });
    final body = await _get(uri);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final stopTimes = json['stopTimes'] as List<dynamic>? ?? const [];
    return stopTimes
        .map((e) => Departure.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Véhicules circulant actuellement dans la zone donnée.
  Future<List<Vehicle>> vehiclesInArea(
    LatLng southWest,
    LatLng northEast, {
    int zoom = 15,
  }) async {
    final now = DateTime.now().toUtc();
    final uri = Uri.https(_baseUrl, '/api/v1/map/trips', {
      'min': '${southWest.latitude},${southWest.longitude}',
      'max': '${northEast.latitude},${northEast.longitude}',
      'startTime': now.toIso8601String(),
      'endTime': now.add(const Duration(minutes: 1)).toIso8601String(),
      'zoom': '$zoom',
    });
    final body = await _get(uri);
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recherche d'arrêts/lieux par nom.
  Future<List<Stop>> geocodeStops(String query, {LatLng? near}) async {
    final params = <String, String>{
      'text': query,
      'type': 'STOP',
    };
    if (near != null) {
      params['place'] = '${near.latitude},${near.longitude}';
      params['placeBias'] = '2';
    }
    final uri = Uri.https(_baseUrl, '/api/v1/geocode', params);
    final body = await _get(uri);
    final list = jsonDecode(body) as List<dynamic>;
    return list
        .where((e) => (e as Map<String, dynamic>)['type'] == 'STOP')
        .map((e) {
      final json = e as Map<String, dynamic>;
      return Stop(
        stopId: json['id'] as String,
        name: json['name'] as String? ?? 'Arrêt',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        modes: const [],
      );
    }).toList();
  }

  Future<String> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw TransitousApiException(
        'Erreur ${response.statusCode} depuis l\'API Transitous',
      );
    }
    return utf8.decode(response.bodyBytes);
  }

  void dispose() => _client.close();
}

class TransitousApiException implements Exception {
  final String message;
  const TransitousApiException(this.message);

  @override
  String toString() => message;
}
