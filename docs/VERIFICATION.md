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
| Tests Swift du moteur | **13 écrits, pas encore exécutés** |
| Compilation Apple | **Pas encore exécutée** |
| Lancement simulateur | **Pas encore exécuté** |
| Installation sur iPad | **Non effectuée** |
| HDMI / son HDMI / charge simultanée | **Non testés** |
| Lecture réelle 24–36 heures | **Non effectuée** |

Les contrôles Python sont des vérifications de structure, pas des tests de comportement Swift. Le workflow macOS doit encore produire les preuves de compilation et de test ; ce document sera mis à jour avec ses résultats réels.
