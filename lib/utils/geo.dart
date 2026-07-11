import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

/// Longueur totale d'une polyline en mètres.
double polylineLength(List<LatLng> points) {
  if (points.length < 2) return 0;
  var total = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    total += _distance(points[i], points[i + 1]);
  }
  return total;
}

/// Résultat de la projection d'un point sur une polyline.
class SnapResult {
  /// Point le plus proche appartenant à la polyline.
  final LatLng point;

  /// Distance (m) entre le point d'origine et [point].
  final double distanceToPath;

  /// Distance (m) parcourue le long de la polyline jusqu'à [point].
  final double distanceAlong;

  const SnapResult({
    required this.point,
    required this.distanceToPath,
    required this.distanceAlong,
  });
}

/// Projette [target] sur la polyline [points] et renvoie le point le plus
/// proche, la distance à ce point et la distance parcourue depuis le début.
///
/// Utilise une approximation planaire locale (valable sur de courtes
/// distances), suffisante pour suivre la progression le long d'un trajet.
SnapResult? snapToPolyline(List<LatLng> points, LatLng target) {
  if (points.isEmpty) return null;
  if (points.length == 1) {
    return SnapResult(
      point: points.first,
      distanceToPath: _distance(target, points.first),
      distanceAlong: 0,
    );
  }

  // Facteur de conversion degré -> mètre autour de la latitude cible.
  const metersPerDegLat = 111320.0;
  final metersPerDegLon =
      metersPerDegLat * math.cos(target.latitude * math.pi / 180);

  double toX(double lon) => lon * metersPerDegLon;
  double toY(double lat) => lat * metersPerDegLat;

  final px = toX(target.longitude);
  final py = toY(target.latitude);

  SnapResult? best;
  var accumulated = 0.0;

  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final segmentLength = _distance(a, b);

    final ax = toX(a.longitude);
    final ay = toY(a.latitude);
    final bx = toX(b.longitude);
    final by = toY(b.latitude);

    final dx = bx - ax;
    final dy = by - ay;
    final segSq = dx * dx + dy * dy;

    double t;
    if (segSq == 0) {
      t = 0;
    } else {
      t = ((px - ax) * dx + (py - ay) * dy) / segSq;
      t = t.clamp(0.0, 1.0);
    }

    final projLat = a.latitude + (b.latitude - a.latitude) * t;
    final projLon = a.longitude + (b.longitude - a.longitude) * t;
    final projected = LatLng(projLat, projLon);
    final distToPath = _distance(target, projected);

    if (best == null || distToPath < best.distanceToPath) {
      best = SnapResult(
        point: projected,
        distanceToPath: distToPath,
        distanceAlong: accumulated + segmentLength * t,
      );
    }
    accumulated += segmentLength;
  }
  return best;
}

/// Point situé à [distanceAlong] mètres depuis le début de la polyline.
LatLng? pointAlong(List<LatLng> points, double distanceAlong) {
  if (points.isEmpty) return null;
  if (points.length == 1 || distanceAlong <= 0) return points.first;

  var remaining = distanceAlong;
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final segmentLength = _distance(a, b);
    if (remaining <= segmentLength || i == points.length - 2) {
      final t = segmentLength == 0 ? 0.0 : (remaining / segmentLength).clamp(0.0, 1.0);
      return LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
    }
    remaining -= segmentLength;
  }
  return points.last;
}

/// Sépare une polyline en deux parties au point situé à [distanceAlong] mètres :
/// la partie déjà parcourue et celle qu'il reste à parcourir.
({List<LatLng> travelled, List<LatLng> remaining}) splitPolyline(
  List<LatLng> points,
  double distanceAlong,
) {
  if (points.length < 2) {
    return (travelled: const [], remaining: points);
  }
  final travelled = <LatLng>[points.first];
  final remaining = <LatLng>[];
  var accumulated = 0.0;
  var splitDone = false;

  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final segmentLength = _distance(a, b);

    if (!splitDone && accumulated + segmentLength >= distanceAlong) {
      final t = segmentLength == 0
          ? 0.0
          : ((distanceAlong - accumulated) / segmentLength).clamp(0.0, 1.0);
      final split = LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      );
      travelled.add(split);
      remaining.add(split);
      splitDone = true;
    }

    if (splitDone) {
      remaining.add(b);
    } else {
      travelled.add(b);
    }
    accumulated += segmentLength;
  }

  if (!splitDone) {
    return (travelled: points, remaining: const []);
  }
  return (travelled: travelled, remaining: remaining);
}
