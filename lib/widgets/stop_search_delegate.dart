import 'package:flutter/material.dart';

import '../models/stop.dart';
import '../state/transit_state.dart';

/// Recherche d'arrêts par nom via le géocodeur Transitous.
class StopSearchDelegate extends SearchDelegate<Stop?> {
  final TransitState state;

  StopSearchDelegate(this.state)
      : super(searchFieldLabel: 'Rechercher un arrêt, une gare…');

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
      return const Center(
        child: Text('Saisissez au moins 2 caractères.'),
      );
    }
    return FutureBuilder<List<Stop>>(
      future: state.searchStops(query.trim()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur de recherche : ${snapshot.error}'),
          );
        }
        final results = snapshot.data ?? const [];
        if (results.isEmpty) {
          return const Center(child: Text('Aucun arrêt trouvé.'));
        }
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final stop = results[index];
            return ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(stop.name),
              onTap: () => close(context, stop),
            );
          },
        );
      },
    );
  }
}
