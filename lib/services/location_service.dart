import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Gère la permission et la récupération de la position de l'utilisateur.
class LocationService {
  /// Position par défaut (Paris, Châtelet) si la localisation est refusée
  /// ou indisponible : l'application reste utilisable partout.
  static const LatLng fallback = LatLng(48.8583, 2.3470);

  Future<LatLng?> currentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
      return null;
    }
  }

  /// Flux de positions pour suivre l'utilisateur en continu.
  Stream<LatLng> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).map((p) => LatLng(p.latitude, p.longitude));
  }
}
