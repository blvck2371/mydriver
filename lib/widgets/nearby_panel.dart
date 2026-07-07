import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/departure.dart';
import '../models/stop.dart';
import '../models/transit_mode.dart';
import '../state/transit_state.dart';
import '../utils/color_utils.dart';
import 'mode_badge.dart';
import 'trip_sheet.dart' show formatDistance;

/// Panneau d'accueil : champ de recherche d'adresse + liste des transports
/// les plus proches partant dans moins de 20 minutes (temps réel).
class NearbyPanel extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onSearchTap;
  final ValueChanged<Stop> onDepartureSelected;

  const NearbyPanel({
    super.key,
    required this.scrollController,
    required this.onSearchTap,
    required this.onDepartureSelected,
  });

  @override
  State<NearbyPanel> createState() => _NearbyPanelState();
}

class _NearbyPanelState extends State<NearbyPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Rafraîchit l'affichage des minutes restantes sans nouvel appel réseau.
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransitState>();
    final theme = Theme.of(context);
    // Recalcule le décompte à l'affichage pour rester à la minute près.
    final now = DateTime.now();
    final items = state.nearbyDepartures
        .where((n) => n.departure.minutesUntil(now) >= 0)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _SearchField(onTap: widget.onSearchTap),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.near_me, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Autour de vous',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '≤ 20 min',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (state.loadingNearby)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList(context, state, items, now)),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    TransitState state,
    List<NearbyDeparture> items,
    DateTime now,
  ) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      // Reste défilable pour permettre de replier la feuille.
      return ListView(
        controller: widget.scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Text(
              state.loadingNearby
                  ? 'Recherche des transports proches…'
                  : state.locationDenied
                      ? 'Activez la localisation pour voir les transports autour de vous.'
                      : 'Aucun transport dans les 20 prochaines minutes autour de vous.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 68),
      itemBuilder: (context, index) => _NearbyTile(
        item: items[index],
        now: now,
        onTap: () => widget.onDepartureSelected(items[index].stop),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(28),
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Où allez-vous ? (adresse, lieu…)',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(Icons.directions, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyTile extends StatelessWidget {
  final NearbyDeparture item;
  final DateTime now;
  final VoidCallback onTap;

  const _NearbyTile({
    required this.item,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final departure = item.departure;
    final mode = TransitMode.fromApi(departure.mode);
    final minutes = departure.minutesUntil(now);

    final lineColor = hexColor(departure.routeColor, mode.color);
    final lineTextColor = hexColor(departure.routeTextColor, Colors.white);

    final timeLabel = minutes <= 0 ? "à l'instant" : '$minutes min';

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 52,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModeBadge(mode: mode, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: lineColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  departure.routeShortName,
                  style: TextStyle(
                    color: lineTextColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
      title: Text(
        departure.headsign.isEmpty ? mode.label : departure.headsign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Icon(Icons.place, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              item.stop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatDistance(item.distanceMeters),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (departure.realTime) ...[
            const SizedBox(width: 6),
            Icon(Icons.rss_feed, size: 12, color: Colors.green.shade600),
          ],
        ],
      ),
      trailing: Text(
        timeLabel,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: minutes <= 5
              ? Colors.green.shade600
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
