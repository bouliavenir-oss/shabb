# ShabbatTV iPad

Application native iPadOS 17+ en SwiftUI / AVFoundation pour préparer une diffusion locale à heures fixes et une sortie externe sans commandes. **Version de développement : ne pas utiliser pour un Shabbat réel avant validation sur iPad.**

Première vérification Apple réussie : 13 tests Swift, compilation simulateur, archive appareil non signée et lancement sur simulateur. Voir [les preuves et limites](docs/VERIFICATION.md). Aucun test HDMI physique ni test réel de 36 h n’a été effectué.

## Ce que contient cette première version

- Import multiple depuis Fichiers, copie dans Application Support, analyse AVFoundation, SHA-256, détection des doublons.
- Bibliothèque avec recherche, renommage, suppression protégée des films programmés et prévisualisation sur iPad.
- Créneaux multi-jours avec début/fin absolus, copie à la suite, détection des conflits et politique explicite pour les changements d’heure.
- Moteur indépendant de l’interface : horloge réelle, intervalles `[début, fin[`, noir/silence en dehors des films, gain par créneau et plafond nocturne.
- AVPlayer local, rattrapage de dérive, deux tentatives de récupération puis noir jusqu’au prochain créneau.
- Scène externe non interactive, proportions conservées, gestion connexion/déconnexion. Sans scène externe, la surface vidéo iPad peut être reflétée par le système.
- Vérification hors ligne avec relecture complète des empreintes, journal JSONL borné et export, surveillance batterie/état thermique.
- Projet Xcode partagé, 13 tests Swift du moteur et workflow GitHub Actions macOS.

## Démarrage développeur

Ouvrir `ShabbatTV.xcodeproj` avec Xcode sur macOS. Choisir le schéma **ShabbatTV** et un simulateur iPad, puis Run. Le projet n’a aucune dépendance tierce.

```sh
swift test
python3 scripts/check_project.py
xcodebuild -project ShabbatTV.xcodeproj -scheme ShabbatTV -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Le dossier `ios/Scheduler` est aussi un package Swift testable sans UIKit. Les tests simulant 36 h du calendrier prennent quelques secondes : **ils ne remplacent pas 36 h de lecture réelle**.

## Installation

Voir [le guide d’installation](docs/INSTALLATION.md). Le workflow produit une archive **non signée et non installable**. Un compte Apple Developer est nécessaire pour TestFlight. GitHub ne remplace pas la signature Apple. Ne jamais mettre de certificat, clé privée ou vidéo dans le dépôt.

## Documentation

- [Utilisation en français](docs/UTILISATION.md)
- [Architecture et état des fonctionnalités](docs/ARCHITECTURE.md)
- [Analyse de la version Windows](docs/PORTAGE-WINDOWS.md)
- [Protocole matériel de 36 heures](docs/VALIDATION-36H.md)
- [État de livraison et limites](docs/ETAT-LIVRAISON.md)

La version Windows existante n’est pas modifiée. Le Cloud, les miniatures, le glisser-déposer, les sous-titres/pistes sélectionnables et la normalisation LUFS sont des phases ultérieures. La grille initiale est une liste chronologique éditable, pas encore une frise proportionnelle avec glisser-déposer.
