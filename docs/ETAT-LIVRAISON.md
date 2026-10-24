# État de livraison — 25 octobre 2026

Première implémentation du MVP local. **Ce projet ne constitue pas encore une application installée ni qualifiée pour Shabbat.**

## Présent dans le code

Bibliothèque locale, imports multiples, SHA-256, contrôle des formats via AVFoundation, protection des médias programmés, recherche/renommage, lecteur de prévisualisation iPad, calendrier absolu, programmation/copie/édition/suppression, volumes et plafond nocturne, mode autonome, scène externe dédiée, reprise limitée, préparation et diagnostics.

## Vérification

Les résultats réellement obtenus sont consignés dans `VERIFICATION.md` après exécution. Un workflow défini mais non exécuté ne vaut pas compilation. Les tests du moteur ne valent pas tests du lecteur ou du matériel.

## Restant avant installation/qualification

- Compte Apple Developer non disponible ; signature, App Store Connect et TestFlight non configurés.
- Aucun essai sur iPad ni télévision, aucune mesure de 24/36 h.
- Icônes de distribution et manifeste de confidentialité Apple à compléter avant TestFlight/App Store.
- Tests d’intégration du stockage et d’AVPlayer à ajouter sur outils Apple.
- Précision des transitions, codecs, route HDMI, Accès guidé et consommation à mesurer.

## Fonctions non encore implémentées

Miniatures, catégories, frise proportionnelle et glisser-déposer, profils Shabbat/Yom Tov, calendrier religieux automatique, sélection des pistes/sous-titres, import de grille Windows, restauration d’exports, fondus/préchargement, nettoyage des fichiers orphelins, Cloud et téléchargements, normalisation LUFS et statistiques longues durées. Le diagnostic affiche les événements de la session en mémoire et exporte le journal disque ; l’accueil ne présente pas encore un résumé de la dernière exécution.

## Limites connues

AVFoundation `isPlayable` et SHA-256 ne décodent pas toutes les images : tester chaque fichier. La sortie HDMI ne peut être certifiée par la seule détection d’une scène. Aucun contrôle du volume physique de la TV. Une interruption sans autorisation de reprise ou une réinitialisation des services multimédias peut laisser le programme noir jusqu’à intervention. La fermeture système/crash/redémarrage ne peut pas être récupérée automatiquement. Le noir affiche du noir ; il n’éteint pas le rétroéclairage du téléviseur. Les gros imports n’ont pas encore de pourcentage en octets ; l’interface montre le fichier courant et le nombre de fichiers.

Prochaine étape : compiler sur macOS, corriger les erreurs détectées, signer après inscription Apple, puis tester le premier film et dix transitions sur l’iPad cible.
