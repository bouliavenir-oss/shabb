# Architecture et décisions

## Modules

| Module | Rôle |
|---|---|
| UI | SwiftUI, écrans français, aucune règle de sélection du programme actif |
| App | Modèle observable MainActor, édition interdite durant la diffusion, orchestration des vérifications |
| Scheduler | Types Codable/Sendable, moteur pur Foundation, temps absolus et politique DST |
| Storage | Actor, copies durables, validation AVFoundation, hachage en flux, sauvegarde atomique |
| Player | AVPlayer local, horloge contrôlée toutes les 250 ms, reprise bornée |
| HDMI | UIKit scene lifecycle, fenêtre externe noire sans contrôles |
| Diagnostics | JSONL + OSLog, 300 événements en mémoire, rotation 4 Mo plus un fichier précédent |

Les médias sont dans Application Support/Media, exclus de la sauvegarde iCloud pour éviter de dupliquer des gigaoctets. Les métadonnées sont dans un seul document JSON versionné, écrit atomiquement. Cette décision remplace SQLite pour ce premier petit catalogue personnel ; un stockage transactionnel SQLite deviendra utile avec la synchronisation multi-appareils. Aucun cache système ne contient la copie de lecture faisant autorité. Pas de suppression automatique des vidéos.

Un crash entre copie et sauvegarde peut laisser un fichier orphelin : il n’est jamais considéré comme média prêt. Le nettoyage des orphelins et des anciens `.partial` après crash reste à développer. Un fichier de bibliothèque corrompu bloque les écritures, sans le remplacer par une liste vide.

## Machine à états

`idle → loading → playing`; à tout créneau vide : `black`. Chargement >15 s, item en erreur ou progression bloquée >12 s : `recovering` (deux nouvelles tentatives pour le créneau), puis `failed` avec sortie noire. Le créneau suivant reste à son heure. Une interruption audio mène à `interrupted`; reprise uniquement si le système fournit `shouldResume`. Arrière-plan : noir, reprise et recalage lorsque l’application redevient active. Réinitialisation des services multimédias : `failed` jusqu’au relancement manuel, conformément à la documentation Apple.

Une génération invalide les callbacks de seek devenus obsolètes. Une nouvelle vérification du créneau dans le callback empêche de rendre visible le film précédent après une transition. Les créneaux et fichiers sont figés au lancement. La fin d’un film court produit du noir ; la fin du créneau coupe un film long. Un conflit résiduel produit du noir. Pas de décalage en cascade.

La précision visée est celle de la boucle de 250 ms plus le délai de décodage/seek et de scheduling du système ; aucune transition instantanée n’est promise. Le préchargement du média suivant et les fondus audio restent à développer après mesures matérielles.

## Horaires

Début/fin stockés comme Date absolues. Fuseau IANA conservé dans le planning, utilisé pour l’affichage et le plafond nocturne. Une modification du fuseau de l’iPad ne réinterprète pas les créneaux. À la saisie, `Calendar` strict rejette les heures inexistantes et une option choisit la première ou seconde occurrence d’une heure répétée. Un changement manuel de l’horloge système est suivi par le moteur ; un saut en arrière peut relire une partie du film.

## Audio et écran externe

AVAudioSession `.playback/.moviePlayback` et routage choisi par iPadOS ; aucune API ne force arbitrairement une route HDMI ni le volume physique du téléviseur. Le gain AVPlayer est plafonné ; ce n’est ni un limiteur de crêtes ni une mesure LUFS. Le noir est une surface noire, pas l’extinction du téléviseur. Le rétroéclairage et les indications propres au téléviseur restent hors du contrôle de l’application.

Le code cible la scène non interactive des versions iPadOS 17–26. La documentation Apple décrit une évolution pour iOS 27 utilisant les accessoires de scène : une adaptation sera nécessaire avant de prétendre supporter ce nouveau cycle de vie. Compatibilité Stage Manager, miroir et hubs : à mesurer sur matériel, pas déduite de la compilation.

## Extension Cloud

Le lecteur n’acceptera toujours que des URLs locales validées. Un futur service de synchronisation séparé déposera un fichier `.partial`, vérifiera taille et SHA-256, puis effectuera un renommage atomique et une transaction de catalogue. Les identifiants seront dans Keychain ; les liens signés HTTPS serviront uniquement au téléchargement. Stockage S3/R2 et catalogue privé restent à choisir après évaluation des volumes et coûts actuels. Aucune infrastructure payante créée, aucun faux bouton de synchronisation et aucune dépendance réseau pendant la lecture.

## Sources Apple consultées

- [Écrans connectés](https://developer.apple.com/documentation/uikit/presenting-content-on-a-connected-display)
- [Désactivation de la veille](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)
- [Interruptions audio](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [Réinitialisation des services multimédias](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification)
