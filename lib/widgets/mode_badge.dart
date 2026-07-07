import 'package:flutter/material.dart';

import '../models/transit_mode.dart';

/// Petite pastille indiquant un mode de transport (métro, bus, tram…).
class ModeBadge extends StatelessWidget {
  final TransitMode mode;
  final double size;

  const ModeBadge({super.key, required this.mode, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: mode.color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(mode.icon, color: Colors.white, size: size * 0.7),
    );
  }
}
