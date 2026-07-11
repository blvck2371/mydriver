import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/itinerary.dart';
import '../models/transit_mode.dart';
import '../state/transit_state.dart';
import '../utils/color_utils.dart';

/// Panneau inférieur de planification et de suivi d'itinéraire.
///
/// Affiche soit la liste des itinéraires proposés, soit, une fois la
/// navigation démarrée, le temps restant et l'avancement en temps réel.
class TripSheet extends StatelessWidget {
  final ScrollController scrollController;

  const TripSheet({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TransitState>();
    final theme = Theme.of(context);

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
          _Header(state: state),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(context, state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, TransitState state) {
    if (state.planning) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.planError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(state.planError!, textAlign: TextAlign.center),
        ),
      );
    }
    if (state.navigating && state.selectedItinerary != null) {
      return _NavigationView(
        scrollController: scrollController,
        state: state,
      );
    }
    if (state.itineraries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucun itinéraire disponible.'),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: state.itineraries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final itinerary = state.itineraries[index];
        return _ItineraryCard(
          itinerary: itinerary,
          selected: itinerary == state.selectedItinerary,
          onTap: () => context.read<TransitState>().selectItinerary(itinerary),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final TransitState state;
  const _Header({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Row(
        children: [
          Icon(Icons.flag, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.navigating ? 'En route vers' : 'Itinéraire vers',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  state.destinationName ?? 'Destination',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Fermer',
            onPressed: () => context.read<TransitState>().clearTrip(),
          ),
        ],
      ),
    );
  }
}

class _ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;
  final bool selected;
  final VoidCallback onTap;

  const _ItineraryCard({
    required this.itinerary,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    formatDuration(
                        Duration(seconds: itinerary.durationSeconds)),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${formatClock(itinerary.startTime)} → '
                    '${formatClock(itinerary.endTime)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LegChips(itinerary: itinerary),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.transfer_within_a_station,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    itinerary.transfers == 0
                        ? 'Direct'
                        : '${itinerary.transfers} corresp.',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (itinerary.walkDistanceMeters > 0) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.directions_walk,
                        size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      formatDistance(itinerary.walkDistanceMeters),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              if (selected) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.read<TransitState>().startNavigation(),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Démarrer'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegChips extends StatelessWidget {
  final Itinerary itinerary;
  const _LegChips({required this.itinerary});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (var i = 0; i < itinerary.legs.length; i++) {
      final leg = itinerary.legs[i];
      if (leg.isWalk) {
        // On regroupe visuellement la marche.
        chips.add(const Icon(Icons.directions_walk, size: 18));
      } else {
        chips.add(_LineChip(leg: leg));
      }
      if (i != itinerary.legs.length - 1) {
        chips.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Icon(Icons.chevron_right, size: 16),
        ));
      }
    }
    return Wrap(
      spacing: 2,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }
}

class _LineChip extends StatelessWidget {
  final TripLeg leg;
  const _LineChip({required this.leg});

  @override
  Widget build(BuildContext context) {
    final mode = TransitMode.fromApi(leg.mode);
    final color = hexColor(leg.routeColor, mode.color);
    final textColor = hexColor(leg.routeTextColor, Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            leg.routeShortName ?? mode.label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationView extends StatelessWidget {
  final ScrollController scrollController;
  final TransitState state;

  const _NavigationView({
    required this.scrollController,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itinerary = state.selectedItinerary!;
    final remaining = state.remainingDuration ?? Duration.zero;
    final progress = state.tripProgress;
    final currentLeg = state.currentLeg;
    final arrived = remaining.inSeconds <= 30 || progress >= 0.999;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrived ? 'Arrivé·e' : 'Temps restant',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  arrived ? '🎉' : formatDuration(remaining),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Arrivée',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                Text(
                  formatClock(itinerary.endTime),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 6),
        if (state.remainingDistance != null)
          Text(
            'Encore ${formatDistance(state.remainingDistance!)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 16),
        if (currentLeg != null) _CurrentStep(leg: currentLeg),
        const SizedBox(height: 16),
        Text('Étapes', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        ...itinerary.legs.map((leg) => _LegTile(
              leg: leg,
              current: leg == currentLeg,
            )),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.read<TransitState>().stopNavigation(),
          icon: const Icon(Icons.stop),
          label: const Text('Terminer la navigation'),
        ),
      ],
    );
  }
}

class _CurrentStep extends StatelessWidget {
  final TripLeg leg;
  const _CurrentStep({required this.leg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = TransitMode.fromApi(leg.mode);
    final String text;
    if (leg.isWalk) {
      text = 'Marchez vers ${leg.to.name}';
    } else {
      final line = leg.routeShortName ?? mode.label;
      text = 'Prenez $line vers ${leg.headsign ?? leg.to.name}';
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(mode.icon, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegTile extends StatelessWidget {
  final TripLeg leg;
  final bool current;
  const _LegTile({required this.leg, required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mode = TransitMode.fromApi(leg.mode);
    final color = hexColor(leg.routeColor, mode.color);

    final String title;
    final String subtitle;
    if (leg.isWalk) {
      title = 'Marche';
      subtitle = leg.distanceMeters != null
          ? '${formatDistance(leg.distanceMeters!)} · vers ${leg.to.name}'
          : 'vers ${leg.to.name}';
    } else {
      title = '${leg.routeShortName ?? mode.label} · ${leg.headsign ?? leg.to.name}';
      subtitle = 'De ${leg.from.name} à ${leg.to.name}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: current
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: leg.isWalk ? theme.colorScheme.surfaceContainerHighest : color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              mode.icon,
              size: 18,
              color: leg.isWalk ? theme.colorScheme.onSurface : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(
            formatClock(leg.startTime),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// --- Helpers de formatage ---

String formatClock(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest';
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
