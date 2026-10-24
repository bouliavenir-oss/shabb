# ShabbatTV gratuit depuis Safari

Ouvrir https://bouliavenir-oss.github.io/shabb/ sur l’iPad dans Safari, puis Partager → Sur l’écran d’accueil → Ajouter. Ouvrir ensuite cette icône et importer les vidéos depuis Fichiers.

Aucun compte Apple Developer, abonnement ni signature hebdomadaire. Le site public contient uniquement l’application ; les vidéos importées restent dans le stockage local du navigateur, sans téléversement.

La version web propose bibliothèque locale, horaires, pauses noires, réglage audio, vérification intégrale des fichiers et cache hors ligne. Installer avant d’importer, conserver les originaux et attendre « Application disponible hors ligne ». Préparer puis tester en mode avion avec plusieurs transitions.

Garder l’application ouverte, l’iPad alimenté et déverrouillé. La sortie télévision repose sur le miroir de l’écran. Le stockage web peut être supprimé par iPadOS ; les reprises avec son dépendent de Safari. Le HDMI physique, Safari sur iPad et une diffusion réelle de 36 heures restent à valider sur matériel.

Validation de développement : 14 tests du moteur, dont changements d’heure et simulation horaire de 36 heures ; import et prévisualisation vidéo observés dans le navigateur Windows. Une simulation ne remplace pas un essai de longue durée.

Sources dans `web/`. Tests : `node --test web/tests/core.test.mjs`. GitHub Pages publie le contenu de `web/` à la racine de la branche `gh-pages`.
