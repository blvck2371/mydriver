/// Un arrêt de transport en commun renvoyé par l'API Transitous.
class Stop {
  final String stopId;
  final String name;
  final double lat;
  final double lon;
  final List<String> modes;

  const Stop({
    required this.stopId,
    required this.name,
    required this.lat,
    required this.lon,
    required this.modes,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      stopId: (json['parentId'] as String?) ?? json['stopId'] as String,
      name: json['name'] as String? ?? 'Arrêt',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      modes: (json['modes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
