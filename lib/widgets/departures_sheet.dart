import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/departure.dart';
import '../models/transit_mode.dart';
import '../state/transit_state.dart';
import '../utils/color_utils.dart';
import 'mode_badge.dart';

/// Panneau inférieur affichant les prochains départs de l'arrêt sélectionné.
class DeparturesSheet extends StatefulWidget {
  final ScrollController scrollController;

  const DeparturesSheet({super.key, required this.scrollController});

  @override
  State<DeparturesSheet> createState() => _DeparturesSheetState();
}

class _DeparturesSheetState extends State<DeparturesSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
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
    final stop = state.selectedStop;
    final theme = Theme.of(context);
    if (stop == null) return const SizedBox.shrink();

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
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          for (final mode in stop.modes.take(6)) ...[
                            ModeBadge(mode: TransitMode.fromApi(mode)),
                            const SizedBox(width: 4),
                          ],
                          if (stop.modes.isNotEmpty) const SizedBox(width: 4),
                          Text(
                            'Prochains départs',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.read<TransitState>().planTripTo(
                        LatLng(stop.lat, stop.lon),
                        stop.name,
                      ),
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Itinéraire'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.read<TransitState>().clearSelection(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: state.loadingDepartures && state.departures.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.departures.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Aucun départ prévu prochainement à cet arrêt.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: state.departures.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 76),
                        itemBuilder: (context, index) =>
                            _DepartureTile(departure: state.departures[index]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DepartureTile extends StatelessWidget {
  final Departure departure;

  const _DepartureTile({required this.departure});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = TransitMode.fromApi(departure.mode);
    final now = DateTime.now();
    final minutes = departure.minutesUntil(now);

    final lineColor = hexColor(departure.routeColor, mode.color);
    final lineTextColor = hexColor(departure.routeTextColor, Colors.white);

    final String timeLabel;
    if (departure.cancelled) {
      timeLabel = 'Supprimé';
    } else if (minutes <= 0) {
      timeLabel = 'Maintenant';
    } else if (minutes < 60) {
      timeLabel = '$minutes min';
    } else {
      final local = departure.departure.toLocal();
      timeLabel = '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: SizedBox(
        width: 56,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModeBadge(mode: mode, size: 22),
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
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: departure.cancelled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Row(
        children: [
          if (departure.realTime) ...[
            Icon(Icons.rss_feed, size: 14, color: Colors.green.shade600),
            const SizedBox(width: 3),
            Text(
              'Temps réel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (departure.delayMinutes != 0) ...[
              const SizedBox(width: 6),
              Text(
                departure.delayMinutes > 0
                    ? '+${departure.delayMinutes} min'
                    : '${departure.delayMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: departure.delayMinutes > 0
                      ? Colors.orange.shade800
                      : Colors.green.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ] else
            Text(
              departure.agencyName.isEmpty
                  ? 'Horaire théorique'
                  : departure.agencyName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Text(
        timeLabel,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: departure.cancelled
              ? theme.colorScheme.error
              : minutes <= 5
                  ? Colors.green.shade600
                  : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
