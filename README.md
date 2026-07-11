# Transit Proche

Application mobile Flutter qui localise **tous les transports en commun proches de vous, en temps réel** — dans l'esprit de l'application Transit.

## Fonctionnalités

- **Carte interactive** (OpenStreetMap) centrée sur votre position GPS.
- **Arrêts proches** : tous les arrêts de bus, métro, tram, train, ferry… visibles dans la zone affichée, avec une pastille colorée par mode de transport.
- **Véhicules en temps réel** : les bus/trains/trams en circulation apparaissent sur la carte avec leur numéro de ligne, et leur position est interpolée en continu le long de leur itinéraire (rafraîchissement toutes les 15 s).
- **Prochains départs** : touchez un arrêt pour voir les prochains passages, avec :
  - l'heure de passage (ou « X min » / « Maintenant »),
  - l'indicateur **Temps réel** et le retard éventuel (+X min),
  - les départs supprimés barrés,
  - la couleur officielle de chaque ligne.
  - Rafraîchissement automatique toutes les 30 s.
- **Recherche d'arrêts** par nom (géocodeur biaisé vers votre position).
- **Mode dégradé** : si la localisation est refusée, l'application reste utilisable (position par défaut + bandeau d'information).
- Thèmes clair et sombre (Material 3).

## Données : API publique Transitous

L'application utilise l'API publique et gratuite de [Transitous](https://transitous.org) (`api.transitous.org`), un projet communautaire basé sur le moteur [MOTIS](https://github.com/motis-project/motis) qui agrège les flux **GTFS** et **GTFS-RT (temps réel)** de centaines de réseaux de transport dans le monde entier (France : IDFM/RATP/SNCF, et la plupart des réseaux urbains ; couverture mondiale).

Endpoints utilisés :

| Endpoint | Usage |
|---|---|
| `GET /api/v1/map/stops` | Arrêts dans la zone visible de la carte |
| `GET /api/v1/stoptimes` | Prochains départs d'un arrêt (temps réel GTFS-RT) |
| `GET /api/v1/map/trips` | Trajets/véhicules en circulation dans la zone |
| `GET /api/v1/geocode` | Recherche d'arrêts par nom |

Aucune clé d'API n'est nécessaire. Un `User-Agent` identifiant l'application est envoyé, conformément à la politique d'usage de Transitous.

## Architecture

```
lib/
├── main.dart                     # Point d'entrée, thème Material 3
├── models/
│   ├── stop.dart                 # Arrêt (station parente + modes)
│   ├── departure.dart            # Départ avec horaires temps réel/théoriques
│   ├── vehicle.dart              # Véhicule + décodage polyline + interpolation
│   └── transit_mode.dart         # Modes de transport (icônes, couleurs, libellés)
├── services/
│   ├── transitous_api.dart       # Client HTTP de l'API Transitous
│   └── location_service.dart     # Permissions + position GPS (geolocator)
├── state/
│   └── transit_state.dart        # État global (Provider) + minuteries de rafraîchissement
├── screens/
│   └── map_screen.dart           # Écran principal : carte, marqueurs, bandeaux
└── widgets/
    ├── departures_sheet.dart     # Panneau des prochains départs
    ├── stop_search_delegate.dart # Recherche d'arrêts
    └── mode_badge.dart           # Pastille de mode de transport
```

## Lancer l'application

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) ≥ 3.32 (Dart ≥ 3.8).

```bash
flutter pub get
flutter run            # sur un appareil/émulateur Android ou iOS
```

Compilation :

```bash
flutter build apk      # Android
flutter build ios      # iOS (nécessite macOS/Xcode)
```

Tests et analyse statique :

```bash
flutter analyze
flutter test
```

## Permissions

- **Android** : `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET` (déclarées dans le manifeste).
- **iOS** : `NSLocationWhenInUseUsageDescription` (déclarée dans `Info.plist`).

## Crédits

- Données transport : [Transitous](https://transitous.org) / MOTIS et les flux ouverts GTFS/GTFS-RT des opérateurs.
- Fond de carte : © contributeurs [OpenStreetMap](https://www.openstreetmap.org/copyright).
