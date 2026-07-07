/// Un départ (passage) à un arrêt, avec informations temps réel.
class Departure {
  final String tripId;
  final String routeShortName;
  final String headsign;
  final String mode;
  final String agencyName;
  final bool realTime;
  final bool cancelled;
  final DateTime scheduledDeparture;
  final DateTime departure;
  final String? routeColor;
  final String? routeTextColor;

  const Departure({
    required this.tripId,
    required this.routeShortName,
    required this.headsign,
    required this.mode,
    required this.agencyName,
    required this.realTime,
    required this.cancelled,
    required this.scheduledDeparture,
    required this.departure,
    this.routeColor,
    this.routeTextColor,
  });

  /// Retard en minutes (positif = retard, négatif = avance).
  int get delayMinutes =>
      departure.difference(scheduledDeparture).inMinutes;

  /// Minutes restantes avant le départ.
  int minutesUntil(DateTime now) => departure.difference(now).inMinutes;

  factory Departure.fromJson(Map<String, dynamic> json) {
    final place = json['place'] as Map<String, dynamic>? ?? const {};
    final scheduled = DateTime.parse(
      (place['scheduledDeparture'] ?? place['scheduledArrival']) as String,
    );
    final actual = DateTime.parse(
      (place['departure'] ?? place['arrival']) as String,
    );
    return Departure(
      tripId: json['tripId'] as String? ?? '',
      routeShortName: (json['displayName'] as String?) ??
          (json['routeShortName'] as String?) ??
          '?',
      headsign: json['headsign'] as String? ?? '',
      mode: json['mode'] as String? ?? 'OTHER',
      agencyName: json['agencyName'] as String? ?? '',
      realTime: json['realTime'] as bool? ?? false,
      cancelled: (json['cancelled'] as bool? ?? false) ||
          (json['tripCancelled'] as bool? ?? false),
      scheduledDeparture: scheduled,
      departure: actual,
      routeColor: _cleanColor(json['routeColor'] as String?),
      routeTextColor: _cleanColor(json['routeTextColor'] as String?),
    );
  }

  static String? _cleanColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    return cleaned.length == 6 ? cleaned : null;
  }
}
