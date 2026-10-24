# Vérifications observées

Date : 25 octobre 2026.

| Vérification | Résultat observé |
|---|---|
| Analyse du source Windows 6.7.1 accessible | Effectuée en lecture seule |
| Création du projet Xcode et du schéma partagé | Effectuée |
| Génération reproductible du projet | Réussie sous Python 3.10 / Windows |
| Référencement unique de chaque source Swift | Réussi |
| Manifest de scènes et cible iPad | Vérifié structurellement |
| Références du schéma partagé | Vérifiées structurellement |
| Absence de clés privées et vidéos dans les sources | Contrôle local réussi |
| Absence d’API réseau dans lecteur/calendrier/HDMI | Contrôle local réussi |
| Total des contrôles Python | **6 réussis** |
| Tests Swift du moteur | **13 exécutés sur macOS, 0 échec** |
| Compilation Apple pour simulateur | **Réussie, Xcode 16.4 / Swift 6.1.2** |
| Archive Apple pour appareil | **Réussie, non signée et non installable** |
| Lancement simulateur | **Réussi, accueil visible sur la capture produite par GitHub** |
| Installation sur iPad | **Non effectuée** |
| HDMI / son HDMI / charge simultanée | **Non testés** |
| Lecture réelle 24–36 heures | **Non effectuée** |

Preuve : [exécution GitHub Actions 40137920609](https://github.com/bouliavenir-oss/shabb/actions/runs/40137920609), commit `f199989`. Résultat global : succès. Artefacts : `iPad-simulator-screen` et `ShabbatTV-unsigned-not-installable`. L’écran d’accueil a été inspecté visuellement. La date affichée sur la capture est celle du simulateur hébergé ; le présent rapport utilise la date locale du projet.

Le premier archivage a signalé une orientation iPad manquante : portrait inversé ajouté dans une correction séparée. L’autre message indique que l’extraction App Intents est ignorée car cette application ne dépend pas d’AppIntents ; il ne bloque pas la construction.

Les contrôles Python sont des vérifications de structure. Les 13 tests Swift exécutent le moteur Foundation réel. Le lancement du simulateur est un test de démarrage, pas une validation de lecture, d’import ou de sortie HDMI. La simulation horaire de 36 h n’est pas un test réel de diffusion de 36 h.
