# Grille d'évaluation — Projet final « Tickets »

**Total : 100 points** — seuil de réussite : **70/100** et **aucun critère éliminatoire** (voir en bas).

## A. Validation automatique (50 points) — `./lab check 25`

| Section | Points |
|---------|:------:|
| 1. Unité systemd (validité, non-root, redémarrage, durcissement ≥ 6) | 6 |
| 2. nginx (proxy, en-têtes, gzip, limite 429, journal dédié) | 9 |
| 3. `backup.sh` (archive, empreintes, rétention, dry-run, codes retour) | 9 |
| 4. `healthcheck.sh` (contrat Nagios 0/1/2/3, perfdata, timeout) | 6 |
| 5. Sécurité (nftables, sshd, sysctl) | 6 |
| 6. Ansible (déploiement, modes, Vault, **idempotence**, handlers) | 10 |
| 7. Documentation (README, RUNBOOK, PRA) | 2 |
| 8. Hygiène du dépôt et des secrets | 2 |

*Score proportionnel au pourcentage de contrôles réussis dans chaque section.*

## B. Qualité technique du code (20 points) — revue par le jury

| Critère | 0 – insuffisant | 1 – à améliorer | 2 – bon | 3-4 – excellent |
|---------|-----------------|-----------------|---------|-----------------|
| **Scripts** : robustesse (`set -euo pipefail`, guillemets, codes retour, nettoyage), lisibilité, `shellcheck` propre | | | | |
| **Idempotence et simplicité Ansible** : modules adaptés (pas de `shell` inutile), noms de tâches explicites, variables, `no_log` sur les secrets | | | | |
| **Sécurité** : moindre privilège, pas de port interne exposé, secrets chiffrés, durcissement pertinent | | | | |
| **Cohérence d'ensemble** : mêmes ports/chemins partout, pas de valeur « magique » dupliquée | | | | |
| **Historique git** : commits atomiques et messages clairs | | | | |

## C. Documentation et exploitabilité (10 points)

- **README** compréhensible par un nouvel arrivant (architecture, installation, exploitation) – 3 pts
- **RUNBOOK** : diagnostics et actions précis, vérifications, escalade – 4 pts
- **PRA** : objectifs réalistes et justifiés, procédure testable, rôles/contacts – 3 pts

## D. Soutenance et démonstration (20 points)

| Critère | Points |
|---------|:------:|
| Clarté et structure de la présentation (10 min), respect du temps | 4 |
| Déploiement Ansible **depuis zéro** en direct, sans improvisation | 5 |
| **Panne simulée et restauration chronométrée** (RTO annoncé tenu ?) | 6 |
| Réponses aux questions (sécurité, choix techniques, pistes d'évolution) | 5 |

## Critères éliminatoires (note maximale plafonnée à 50/100)

- Secret en clair dans le dépôt (mot de passe, clé privée, `.vault_pass`).
- Port applicatif interne ouvert au pare-feu ou service exécuté en root sans justification.
- Playbook non idempotent ou qui ne fonctionne pas depuis un environnement vierge.
- Plagiat non cité.

## Auto-évaluation avant la soutenance (à cocher)

- [ ] `./lab check 25` : 100 %
- [ ] `shellcheck` propre sur mes scripts
- [ ] Je sais expliquer chaque ligne de mon unité systemd et de mon `nginx` à l'oral
- [ ] J'ai chronométré une restauration complète (< RTO annoncé)
- [ ] Mes commits racontent une histoire cohérente
- [ ] Je peux dire ce que je ferais avec une semaine de plus (TLS, supervision, haute disponibilité…)
