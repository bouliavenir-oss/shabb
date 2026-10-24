# Compilation et installation depuis Windows

## Ce que GitHub peut faire

Chaque push lance le workflow **Apple build and scheduler tests** sur un exécuteur macOS : vérifications du projet, tests Swift, compilation simulateur, archive pour iPad non signée. Le résultat `ShabbatTV-unsigned-not-installable` est réservé à la vérification technique : **ce n’est pas un fichier installable sur iPad**.

Les résultats du workflow doivent être lus avant toute affirmation de compilation réussie. Une archive non signée ne peut pas être rendue installable en changeant son extension en `.ipa`.

## Chemin recommandé : TestFlight

Le propriétaire n’a actuellement pas de compte Apple Developer. Les étapes suivantes restent donc indispensables :

1. S’inscrire personnellement à l’[Apple Developer Program](https://developer.apple.com/programs/enroll/) avec son compte Apple et terminer la vérification/adhésion sur le site Apple. Ne transmettre aucun mot de passe à l’assistant.
2. Dans App Store Connect, créer l’application ShabbatTV avec un identifiant unique appartenant au compte. Remplacer `com.shabbattv.ipad` si nécessaire.
3. Sur un Mac personnel ou distant autorisé, ouvrir le projet Xcode, sélectionner l’équipe dans **Signing & Capabilities**, choisir **Any iOS Device**, puis **Product → Archive** et **Distribute App → App Store Connect**. L’icône et le manifeste sont inclus ; compléter les déclarations App Store Connect avant validation de distribution.
4. Ajouter le compte comme testeur interne et installer TestFlight sur l’iPad. Accepter l’invitation et installer la version traitée par Apple.
5. Faire les essais du guide matériel. Un build TestFlight expire après **90 jours** : renouveler et tester avant un voyage, jamais pendant Shabbat.

L’archivage signé peut ensuite être automatisé sur GitHub avec un environnement de distribution protégé : certificat et profil dans des secrets GitHub, keychain temporaire supprimée en fin de job, clé App Store Connect à privilèges minimaux. Ce workflow de signature n’est pas activé dans cette livraison : aucun compte, certificat ou identifiant d’équipe n’est encore disponible. Ne pas publier les secrets dans un fichier, une issue ou une conversation.

## Sans abonnement Apple Developer

Un essai personnel via Xcode et une équipe personnelle peut être envisagé avec un Mac et les restrictions de provisioning correspondantes. Ce n’est pas une distribution TestFlight durable depuis Windows. Le parcours le plus simple pour les voyages reste TestFlight pendant les essais, puis une distribution Apple adaptée après validation. La création du dépôt et les compilations non signées n’exigent pas l’inscription Developer.

## Références

- [Distribution bêta Apple](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [Distribution aux appareils enregistrés](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices)
- [Durée de validité TestFlight](https://testflight.apple.com/)
