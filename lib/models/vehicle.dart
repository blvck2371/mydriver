import 'package:latlong2/latlong.dart';

/// Un véhicule (trajet en cours) renvoyé par `/api/v1/map/trips`.
///
/// L'API fournit le segment de trajet dans la fenêtre temporelle demandée :
/// on interpole la position du véhicule le long de la polyline entre
/// l'heure de départ et l'heure d'arrivée du segment.
class Vehicle {
  final String tripId;
  final String routeShortName;
  final String mode;
  final bool realTime;
  final String? routeColor;
  final DateTime departure;
  final DateTime arrival;
  final List<LatLng> polyline;

  const Vehicle({
    required this.tripId,
    required this.routeShortName,
    required this.mode,
    required this.realTime,
    required this.departure,
    required this.arrival,
    required this.polyline,
    this.routeColor,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final trips = json['trips'] as List<dynamic>? ?? const [];
    final firstTrip =
        trips.isNotEmpty ? trips.first as Map<String, dynamic> : const {};
    return Vehicle(
      tripId: firstTrip['tripId'] as String? ?? '',
      routeShortName: firstTrip['routeShortName'] as String? ?? '?',
      mode: json['mode'] as String? ?? 'OTHER',
      realTime: json['realTime'] as bool? ?? false,
      routeColor: _cleanColor(json['routeColor'] as String?),
      departure: DateTime.parse(json['departure'] as String),
      arrival: DateTime.parse(json['arrival'] as String),
      polyline: decodePolyline(json['polyline'] as String? ?? ''),
    );
  }

  static String? _cleanColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    return cleaned.length == 6 ? cleaned : null;
  }

  /// Position estimée du véhicule à l'instant [now] par interpolation
  /// linéaire de la distance parcourue le long de la polyline.
  LatLng? positionAt(DateTime now) {
    if (polyline.isEmpty) return null;
    if (polyline.length == 1) return polyline.first;

    final total = arrival.difference(departure).inSeconds;
    if (total <= 0) return polyline.last;
    final elapsed = now.difference(departure).inSeconds;
    final fraction = (elapsed / total).clamp(0.0, 1.0);

    const distance = Distance();
    double totalLength = 0;
    final segmentLengths = <double>[];
    for (var i = 0; i < polyline.length - 1; i++) {
      final d = distance(polyline[i], polyline[i + 1]);
      segmentLengths.add(d);
      totalLength += d;
    }
    if (totalLength == 0) return polyline.first;

    var target = totalLength * fraction;
    for (var i = 0; i < segmentLengths.length; i++) {
      if (target <= segmentLengths[i]) {
        final t = segmentLengths[i] == 0 ? 0.0 : target / segmentLengths[i];
        final a = polyline[i];
        final b = polyline[i + 1];
        return LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
      }
      target -= segmentLengths[i];
    }
    return polyline.last;
  }
}

/// Décode une polyline encodée Google (précision 5, utilisée par Transitous).
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final coords = <LatLng>[];
  final factor = 1 / _pow10(precision);
  var index = 0;
  var lat = 0;
  var lon = 0;

  while (index < encoded.length) {
    for (var coord = 0; coord < 2; coord++) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      if (coord == 0) {
        lat += delta;
      } else {
        lon += delta;
      }
    }
    coords.add(LatLng(lat * factor, lon * factor));
  }
  return coords;
}

double _pow10(int n) {
  var value = 1.0;
  for (var i = 0; i < n; i++) {
    value *= 10;
  }
  return value;
}
