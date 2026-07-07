import 'package:flutter/material.dart';

/// Modes de transport renvoyés par l'API Transitous (MOTIS),
/// avec leur apparence dans l'application.
enum TransitMode {
  bus('BUS', 'Bus', Icons.directions_bus, Color(0xFF1E88E5)),
  subway('SUBWAY', 'Métro', Icons.subway, Color(0xFFE53935)),
  tram('TRAM', 'Tram', Icons.tram, Color(0xFF43A047)),
  rail('RAIL', 'Train', Icons.train, Color(0xFF5E35B1)),
  suburban('SUBURBAN', 'RER', Icons.directions_transit, Color(0xFF00838F)),
  regionalRail('REGIONAL_RAIL', 'TER', Icons.directions_railway,
      Color(0xFF3949AB)),
  regionalFastRail('REGIONAL_FAST_RAIL', 'Train rapide',
      Icons.directions_railway, Color(0xFF3949AB)),
  highspeedRail('HIGHSPEED_RAIL', 'TGV', Icons.train, Color(0xFF8E24AA)),
  longDistance('LONG_DISTANCE', 'Grandes lignes', Icons.train,
      Color(0xFF8E24AA)),
  nightRail('NIGHT_RAIL', 'Train de nuit', Icons.nightlight_round,
      Color(0xFF283593)),
  coach('COACH', 'Car', Icons.directions_bus_filled, Color(0xFF00897B)),
  ferry('FERRY', 'Ferry', Icons.directions_boat, Color(0xFF00ACC1)),
  airplane('AIRPLANE', 'Avion', Icons.flight, Color(0xFF546E7A)),
  funicular('FUNICULAR', 'Funiculaire', Icons.terrain, Color(0xFF6D4C41)),
  aerialLift('AERIAL_LIFT', 'Téléphérique', Icons.cable, Color(0xFF6D4C41)),
  cableCar('CABLE_CAR', 'Téléphérique', Icons.cable, Color(0xFF6D4C41)),
  metro('METRO', 'Métro', Icons.subway, Color(0xFFE53935)),
  walk('WALK', 'Marche', Icons.directions_walk, Color(0xFF616161)),
  bike('BIKE', 'Vélo', Icons.directions_bike, Color(0xFF00897B)),
  rental('RENTAL', 'Vélo partagé', Icons.pedal_bike, Color(0xFF00897B)),
  car('CAR', 'Voiture', Icons.directions_car, Color(0xFF455A64)),
  other('OTHER', 'Transport', Icons.commute, Color(0xFF757575));

  final String apiValue;
  final String label;
  final IconData icon;
  final Color color;

  const TransitMode(this.apiValue, this.label, this.icon, this.color);

  static TransitMode fromApi(String? value) {
    if (value == null) return TransitMode.other;
    return TransitMode.values.firstWhere(
      (m) => m.apiValue == value,
      orElse: () => TransitMode.other,
    );
  }
}
