import 'package:flutter/material.dart';

import '../models/place_suggestion.dart';
import '../state/transit_state.dart';

/// Recherche d'une destination (adresse, lieu ou arrêt) via le géocodeur.
class DestinationSearchDelegate extends SearchDelegate<PlaceSuggestion?> {
  final TransitState state;

  DestinationSearchDelegate(this.state)
      : super(searchFieldLabel: 'Saisir une adresse, un lieu…');

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    if (query.trim().length < 2) {
      return const Center(child: Text('Saisissez au moins 2 caractères.'));
    }
    return FutureBuilder<List<PlaceSuggestion>>(
      future: state.searchPlaces(query.trim()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return const Center(child: Text('Aucun résultat.'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final place = results[index];
            return ListTile(
              leading: Icon(_iconFor(place.type)),
              title: Text(place.name),
              subtitle: place.subtitle.isEmpty ? null : Text(place.subtitle),
              onTap: () => close(context, place),
            );
          },
        );
      },
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'STOP':
        return Icons.directions_transit;
      case 'ADDRESS':
        return Icons.home_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}
