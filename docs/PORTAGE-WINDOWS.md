# Analyse Windows, 25 octobre 2026

Une copie locale accessible de `shabbat_tv.py`, version déclarée **6.7.1**, a été lue. Aucun dépôt Windows accessible via le connecteur GitHub n’a été trouvé. Il s’agit d’une analyse de source, pas d’une vérification de la dernière version publiée. Le fichier original n’a pas été modifié.

| Fonction réellement présente | Indice dans le source | Décision iPad |
|---|---|---|
| Construction et conflits de grille | `Creneau`, `chevauchements`, `construire_grille` | Moteur Foundation indépendant, conflits bloquants |
| Modes libre/enchaîné, heures fixes | `placement_libre`, `fixed_day`, `fixed_start` | Heures absolues uniquement dans le MVP |
| Pauses de lecture et reprise du film interrompu | `pauses`, `Diffuseur._position_contenu` | Non porté : noir explicite, sans décaler les films suivants |
| Films, pistes, durées | `Analyseur.duree`, `pistes`, ffprobe | AVURLAsset natif |
| Mesure loudness -16 LUFS | `Analyseur.loudness`, filtre FFmpeg `loudnorm` | Préparation externe ultérieure ; aucun équivalent inventé dans AVPlayer |
| Gain et volume manuel | `Programme.gain_db`, `volume_pct`, `VolumeSysteme` | Gain par créneau et plafonds, pas contrôle du volume matériel |
| Écran noir UI, secours média noir | `_antenne_noire`, `black_via_ui` | Surface noire native, sans boucle vidéo |
| Reprise du lecteur VLC | `VLC`, `_assurer_vlc` | Recréation AVPlayerItem bornée ; pas de relance de l’application |
| Anti-veille | `AntiVeille` | `UIApplication.isIdleTimerDisabled` au premier plan |
| Frise manipulable | `_tl_press`, `_tl_motion`, `_tl_release` | Liste horaire éditable maintenant ; frise tactile ultérieure |
| Export playlist | `creer_playlist_m3u`, `exporter` | Export JSON du planning, migration des anciens exports à faire |
| Horaires Shabbat calculés / en ligne | `prochain_shabbat`, `coucher_soleil`, `horaires_en_ligne` | Heures saisies et validées avant diffusion ; calcul religieux non porté |
| Tests grandeur et accélération | `lancer_test_grandeur`, `accelerer_test` | Tests du moteur + protocole matériel distinct |

À récupérer pour une migration fidèle : dépôt source faisant autorité, exemples anonymisés de `grille.json`/`config.json`, règles attendues pour les pauses de lecture, choix des sous-titres/pistes, profils Shabbat/Yom Tov. Aucun chemin Windows de vidéo ne sera utilisable directement sur iPad : les films doivent être importés.
