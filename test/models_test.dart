import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transit_proche/models/departure.dart';
import 'package:transit_proche/models/stop.dart';
import 'package:transit_proche/models/vehicle.dart';

void main() {
  group('decodePolyline', () {
    test('décode une polyline Transitous (précision 5)', () {
      final coords = decodePolyline('i|bvHoenJAL`aaLoaaBmHhI');
      expect(coords.length, 4);
      expect(coords.first.latitude, closeTo(50.97429, 1e-5));
      expect(coords.first.longitude, closeTo(1.88008, 1e-5));
      expect(coords.last.latitude, closeTo(48.83532, 1e-5));
      expect(coords.last.longitude, closeTo(2.38052, 1e-5));
    });

    test('renvoie une liste vide pour une chaîne vide', () {
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('Stop.fromJson', () {
    test('utilise parentId comme identifiant de station', () {
      final stop = Stop.fromJson(const {
        'name': 'Châtelet',
        'stopId': 'x_IDFM:493026',
        'parentId': 'x_IDFM:71264',
        'lat': 48.857983,
        'lon': 2.3470986,
        'modes': ['BUS', 'SUBWAY'],
      });
      expect(stop.stopId, 'x_IDFM:71264');
      expect(stop.name, 'Châtelet');
      expect(stop.modes, ['BUS', 'SUBWAY']);
    });
  });

  group('Departure.fromJson', () {
    test('calcule le retard et détecte le temps réel', () {
      final departure = Departure.fromJson(const {
        'place': {
          'scheduledDeparture': '2026-07-07T10:00:00Z',
          'departure': '2026-07-07T10:03:00Z',
        },
        'tripId': 't1',
        'displayName': '38',
        'headsign': 'Porte de la Chapelle',
        'mode': 'BUS',
        'agencyName': 'RATP',
        'realTime': true,
        'cancelled': false,
        'routeColor': '0055c8',
        'routeTextColor': 'ffffff',
      });
      expect(departure.delayMinutes, 3);
      expect(departure.realTime, isTrue);
      expect(departure.routeShortName, '38');
      expect(departure.routeColor, '0055c8');
    });

    test('ignore une couleur invalide', () {
      final departure = Departure.fromJson(const {
        'place': {
          'scheduledDeparture': '2026-07-07T10:00:00Z',
          'departure': '2026-07-07T10:00:00Z',
        },
        'routeColor': '',
      });
      expect(departure.routeColor, isNull);
      expect(departure.delayMinutes, 0);
    });
  });

  group('Vehicle.positionAt', () {
    final vehicle = Vehicle(
      tripId: 't1',
      routeShortName: '38',
      mode: 'BUS',
      realTime: true,
      departure: DateTime.utc(2026, 7, 7, 10, 0),
      arrival: DateTime.utc(2026, 7, 7, 10, 10),
      polyline: const [LatLng(0, 0), LatLng(0, 1)],
    );

    test('au départ, le véhicule est au début de la polyline', () {
      final p = vehicle.positionAt(DateTime.utc(2026, 7, 7, 10, 0));
      expect(p!.longitude, closeTo(0, 1e-9));
    });

    test('à mi-parcours, le véhicule est au milieu', () {
      final p = vehicle.positionAt(DateTime.utc(2026, 7, 7, 10, 5));
      expect(p!.longitude, closeTo(0.5, 1e-9));
    });

    test('après l\'arrivée, le véhicule reste au terminus', () {
      final p = vehicle.positionAt(DateTime.utc(2026, 7, 7, 10, 30));
      expect(p!.longitude, closeTo(1, 1e-9));
    });
  });
}
