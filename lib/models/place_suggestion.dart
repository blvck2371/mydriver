import 'package:latlong2/latlong.dart';

/// Résultat de recherche du géocodeur : arrêt, adresse ou lieu.
class PlaceSuggestion {
  final String name;
  final String subtitle;
  final double lat;
  final double lon;
  final String type;
  final List<String> modes;

  const PlaceSuggestion({
    required this.name,
    required this.subtitle,
    required this.lat,
    required this.lon,
    required this.type,
    this.modes = const [],
  });

  LatLng get latLng => LatLng(lat, lon);

  bool get isStop => type == 'STOP';

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final areas = (json['areas'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    // On privilégie les zones administratives « par défaut » (ville, région).
    final labels = areas
        .where((a) => a['default'] == true)
        .map((a) => a['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (labels.isEmpty && areas.isNotEmpty) {
      labels.add(areas.first['name'] as String? ?? '');
    }

    return PlaceSuggestion(
      name: json['name'] as String? ?? '',
      subtitle: labels.take(2).join(', '),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      type: json['type'] as String? ?? 'PLACE',
      modes: (json['modes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
