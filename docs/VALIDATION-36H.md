# Protocole de validation matérielle — non exécuté

## Identification obligatoire

Noter modèle exact d’iPad, version iPadOS, version/commit ShabbatTV, télévision, résolution, adaptateur USB-C, chargeur, câbles, formats vidéo et empreintes. Aucun résultat de cette fiche n’est présumé réussi.

## A. Tests logiciels

Exécuter `swift test` : limites des créneaux, conflits imbriqués, manque de média, film court/long, rattrapage à l’heure, plafond nocturne, passage été/hiver, sérialisation, simulation de décisions sur 36 h. Lire le résultat GitHub. Ces tests n’exécutent pas AVPlayer et ne prouvent rien sur HDMI.

Ajouter ensuite des tests d’intégration iPad pour erreurs disque, fermeture pendant copie, métadonnées corrompues, fichier tronqué, import de doublons et interruption/reprise. Ils ne sont pas automatisés dans le MVP.

## B. Qualification courte sur appareil

| Essai | Attendu | Résultat observé / preuve |
|---|---|---|
| Import depuis Fichiers puis suppression de l’original | Copie locale continue de fonctionner | À renseigner |
| Film entier, audio et proportions | Image et son corrects | À renseigner |
| 10 transitions rapprochées | Heures respectées, aucun contrôle sur TV | À renseigner |
| Noir de 15 minutes | Noir et silence pendant toute la plage | À renseigner |
| Mode avion + Wi-Fi coupé | Aucun appel réseau nécessaire | À renseigner |
| Film plus court/long que son créneau | Noir/coupure, suivant à heure fixe | À renseigner |
| Débranchement/rebranchement HDMI | Scène recréée, image au bon timecode | À renseigner |
| Charge simultanée | Charge stable, pas de décharge progressive | À renseigner |
| Interruption audio autorisant reprise | Recalage et reprise journalisés | À renseigner |
| Retour au premier plan | Recalage sur horloge, sans cascade | À renseigner |
| Arrêt forcé puis relance manuelle | Bibliothèque restaurée, reprise après lancement | À renseigner |
| Services multimédias réinitialisés | Noir et incident bloquant documenté | À renseigner |
| Accès guidé | Contrôles protégés sans perturber HDMI | À renseigner |

## C. Test réel de 36 heures

Plan représentatif avec au moins 10 films/transitions, différentes résolutions compatibles et une nuit noire. Secteur branché, application au premier plan, aucun réseau. Démarrer avant la période test, puis ne pas intervenir. Tout geste de récupération est compté comme intervention et invalide le critère zéro intervention.

Collecter : journal JSONL et précédent s’il existe, heures réelles d’apparition/disparition sur TV (caméra externe ou observation horodatée), nombre d’interruptions, dérive des transitions, erreurs AVPlayer, charge au début/fin et chaque heure, déconnexions HDMI. Mesurer mémoire avec Instruments sur un essai instrumenté distinct ; l’application ne mesure actuellement pas la mémoire. L’état thermique Apple n’est pas une température en degrés.

Le journal interne ne prouve pas que le téléviseur a réellement affiché chaque image. Croiser avec les observations externes. Archiver les preuves hors du dépôt public si elles contiennent des titres ou informations privées.

## Critère et rapport

Objectif : 36 h sans intervention ni erreur bloquante ; noirs silencieux, volume stable, pas de dérive accumulée. Définir avant l’essai une tolérance de transition (par exemple 2 s), puis mesurer et documenter les écarts. Ne pas transformer l’objectif en garantie.

Rapport à remplir : début/fin, durée mesurée, matériel, version, incidents avec timestamp, retards maximum/médian, consommation observée, mesures mémoire/thermiques disponibles, verdict, corrections et nouvel essai requis.

Si la sortie HDMI ou le maintien au premier plan ne sont pas assez fiables, comparer un petit boîtier HDMI alimenté au secteur : système contrôlable, démarrage automatique réel après coupure, watchdog et stockage local. L’iPad conserve l’avantage de la préparation tactile et du transport ; le boîtier permet une meilleure maîtrise du redémarrage. Aucune conclusion de fiabilité matérielle sans essai comparatif.
