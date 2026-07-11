import 'package:flutter/material.dart';

/// Convertit une couleur hexadécimale GTFS (`RRGGBB` ou `#RRGGBB`, casse
/// indifférente) en [Color]. Renvoie [fallback] si la valeur est absente,
/// vide ou invalide — ce qui évite tout `FormatException` en production.
Color hexColor(String? hex, Color fallback) {
  if (hex == null) return fallback;
  var cleaned = hex.replaceAll('#', '').trim();
  if (cleaned.isEmpty) return fallback;
  if (cleaned.length == 6) cleaned = 'FF$cleaned';
  if (cleaned.length != 8) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  return value == null ? fallback : Color(value);
}

/// Renvoie une couleur de texte lisible (noir ou blanc) sur [background].
Color readableOn(Color background) {
  // Luminance relative simple pour choisir un contraste correct.
  final luminance = background.computeLuminance();
  return luminance > 0.6 ? Colors.black87 : Colors.white;
}
