import 'package:latlong2/latlong.dart';

import 'vehicle.dart' show decodePolyline;

/// Un lieu d'un itinéraire (origine, destination ou arrêt intermédiaire).
class TripPlace {
  final String name;
  final double lat;
  final double lon;
  final DateTime? arrival;
  final DateTime? departure;

  const TripPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.arrival,
    this.departure,
  });

  LatLng get latLng => LatLng(lat, lon);

  factory TripPlace.fromJson(Map<String, dynamic> json) {
    return TripPlace(
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      arrival: _parse(json['arrival']),
      departure: _parse(json['departure']),
    );
  }

  static DateTime? _parse(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// Un segment (leg) d'un itinéraire : soit une portion à pied/vélo, soit un
/// trajet en transport en commun.
class TripLeg {
  final String mode;
  final TripPlace from;
  final TripPlace to;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final double? distanceMeters;
  final String? headsign;
  final String? routeShortName;
  final String? routeLongName;
  final String? routeColor;
  final String? routeTextColor;
  final String? agencyName;
  final bool realTime;
  final bool cancelled;
  final List<LatLng> geometry;
  final List<TripPlace> intermediateStops;

  const TripLeg({
    required this.mode,
    required this.from,
    required this.to,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.geometry,
    required this.intermediateStops,
    this.distanceMeters,
    this.headsign,
    this.routeShortName,
    this.routeLongName,
    this.routeColor,
    this.routeTextColor,
    this.agencyName,
    this.realTime = false,
    this.cancelled = false,
  });

  /// Un leg « rue » (marche, vélo, voiture) plutôt qu'un transport en commun.
  bool get isStreet => const {
        'WALK',
        'BIKE',
        'CAR',
        'CAR_PARKING',
        'CAR_DROPOFF',
        'RENTAL',
        'ODM',
      }.contains(mode);

  bool get isWalk => mode == 'WALK';

  factory TripLeg.fromJson(Map<String, dynamic> json) {
    final geometryJson = json['legGeometry'] as Map<String, dynamic>?;
    final points = geometryJson?['points'] as String? ?? '';
    final precision = (geometryJson?['precision'] as num?)?.toInt() ?? 5;

    final intermediate = (json['intermediateStops'] as List<dynamic>? ?? const [])
        .map((e) => TripPlace.fromJson(e as Map<String, dynamic>))
        .toList();

    return TripLeg(
      mode: json['mode'] as String? ?? 'OTHER',
      from: TripPlace.fromJson(json['from'] as Map<String, dynamic>),
      to: TripPlace.fromJson(json['to'] as Map<String, dynamic>),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      distanceMeters: (json['distance'] as num?)?.toDouble(),
      headsign: json['headsign'] as String?,
      routeShortName: (json['routeShortName'] as String?) ??
          (json['displayName'] as String?),
      routeLongName: json['routeLongName'] as String?,
      routeColor: _cleanColor(json['routeColor'] as String?),
      routeTextColor: _cleanColor(json['routeTextColor'] as String?),
      agencyName: json['agencyName'] as String?,
      realTime: json['realTime'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
      geometry:
          points.isEmpty ? const [] : decodePolyline(points, precision: precision),
      intermediateStops: intermediate,
    );
  }

  static String? _cleanColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    return cleaned.length == 6 ? cleaned : null;
  }
}

/// Un itinéraire complet composé de plusieurs [TripLeg].
class Itinerary {
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int transfers;
  final List<TripLeg> legs;

  const Itinerary({
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.transfers,
    required this.legs,
  });

  /// Legs de transport en commun uniquement.
  List<TripLeg> get transitLegs => legs.where((l) => !l.isStreet).toList();

  /// Distance totale de marche (m).
  double get walkDistanceMeters => legs
      .where((l) => l.isWalk)
      .fold(0.0, (sum, l) => sum + (l.distanceMeters ?? 0));

  /// Tous les points géographiques de l'itinéraire (concaténation des legs).
  List<LatLng> get geometry {
    final points = <LatLng>[];
    for (final leg in legs) {
      for (final p in leg.geometry) {
        if (points.isEmpty || points.last != p) {
          points.add(p);
        }
      }
    }
    return points;
  }

  factory Itinerary.fromJson(Map<String, dynamic> json) {
    final legs = (json['legs'] as List<dynamic>? ?? const [])
        .map((e) => TripLeg.fromJson(e as Map<String, dynamic>))
        .toList();
    return Itinerary(
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      transfers: (json['transfers'] as num?)?.toInt() ?? 0,
      legs: legs,
    );
  }
}
