# Correspondance avec les certifications

Cette formation couvre l'essentiel des compétences évaluées par les principales certifications Linux. Les référentiels évoluent : **vérifiez toujours les objectifs officiels à jour** auprès de l'organisme avant de passer l'examen.

## Vue d'ensemble

| Certification | Organisme | Orientation | Niveau | Format |
|---------------|-----------|-------------|--------|--------|
| **LPIC-1** (101 + 102) | Linux Professional Institute | administration, neutre vis-à-vis des distributions | Junior | 2 examens à questions (QCM / texte à trou) |
| **LPIC-2** (201 + 202) | LPI | administration avancée, réseau, services | Intermédiaire | 2 examens |
| **LPIC-3** (spécialités) | LPI | sécurité, virtualisation/conteneurs, haute disponibilité | Expert | examens par spécialité |
| **RHCSA** | Red Hat (EX200) | administration RHEL (famille Red Hat) | Junior-Intermédiaire | **examen pratique** sur machine |
| **RHCE** | Red Hat (EX294) | automatisation avec Ansible | Intermédiaire-Avancé | examen pratique |
| **LFCS** | Linux Foundation | administration (Ubuntu / Rocky) | Junior-Intermédiaire | **examen pratique** en ligne |
| **CompTIA Linux+** | CompTIA | généraliste, sécurité, scripts, dépannage | Junior-Intermédiaire | QCM + exercices de simulation |
| **CKA / CKAD** | CNCF / Linux Foundation | Kubernetes (administration / développement) | Avancé | examen pratique |

## LPIC-1 → modules de la formation

| Domaine LPIC-1 | Modules |
|----------------|---------|
| Architecture système, installation, gestion des paquets | 01, 08, 13, 21 |
| Commandes GNU et Unix, filtres de texte, flux, regex | 02, 03, 04, 05, 10 |
| Périphériques, systèmes de fichiers Linux, FHS, quotas | 02, 03, 13, 21 |
| Shell et scripts | 04, 05, 09 |
| Tâches d'administration (utilisateurs, cron, journaux, localisation, heure) | 06, 14, 15 |
| Services système essentiels (NTP, syslog, messagerie, impression) | 14, 15, 19 |
| Fondamentaux réseau | 11, 12 |
| Sécurité (permissions, SSH, chiffrement, pare-feu de base) | 06, 12, 16 |
| Interfaces utilisateur et bureaux | hors périmètre (à compléter) |

## RHCSA (RHEL) → modules

| Objectif RHCSA | Modules | Particularités RHEL à pratiquer |
|----------------|---------|---------------------------------|
| Outils essentiels, fichiers, redirections, archives | 02-05, 15 | `tar`, `find`, `grep`, `man` |
| Scripts shell simples | 09 | |
| Systèmes en fonctionnement, processus, `tuned`, démarrage | 07, 14, 18, 21 | `systemctl set-default`, `rd.break`, `tuned-adm` |
| Stockage local, LVM, systèmes de fichiers, swap, **Stratis/VDO** | 13 | `xfs`, `stratis` |
| Déploiement/maintenance : paquets, dépôts, **dnf**, `cron`/timers, NTP | 08, 14 | `dnf`, `rpm`, `chrony` |
| Réseau de base | 11 | **NetworkManager (`nmcli`)**, `firewall-cmd` |
| Utilisateurs, groupes, `sudo`, ACL | 06 | `chage`, `/etc/sudoers.d` |
| Sécurité : **SELinux**, **firewalld**, SSH | 12, 16 | `semanage`, `restorecon`, `setsebool` |
| Conteneurs (Podman, `systemd` pour les conteneurs) | 20 | `podman`, `skopeo`, Quadlet |

> Pour RHCSA, entraînez-vous **sur Rocky/Alma/RHEL** : la formation est basée sur Ubuntu, mais chaque module indique les équivalents (`dnf`, `nmcli`, `firewalld`, SELinux).

## LFCS → modules

| Domaine LFCS | Modules |
|--------------|---------|
| Commandes essentielles | 02-05, 10 |
| Opérations / déploiement (processus, services, journaux, planification, paquets) | 07, 08, 14, 15, 18, 21 |
| Utilisateurs et groupes | 06 |
| Réseau | 11, 12, 16, 17 |
| Stockage | 13 |

## CompTIA Linux+ → modules

| Domaine | Modules |
|---------|---------|
| Gestion du système (arborescence, stockage, réseau, paquets, services) | 02, 03, 07, 08, 11, 13, 14, 21 |
| Services et utilisateurs, sécurité | 06, 12, 16 |
| Automatisation, orchestration, scripts, conteneurs | 09, 20, 22 |
| Dépannage (système, réseau, performance, sécurité) | 11, 17, 18, 23 |

## LPIC-2 / LPIC-3 et au-delà

| Sujet | Modules |
|-------|---------|
| Capacités, performances, noyau, démarrage, stockage avancé, réseau avancé | 13, 17, 18, 21 |
| Serveur web, DNS, DHCP, partage de fichiers, messagerie | 19 (+ approfondissement) |
| Sécurité (LPIC-3 303) | 16, 12 (+ SELinux/AppArmor approfondis) |
| Virtualisation et conteneurs (LPIC-3 305) | 20 |
| Haute disponibilité (LPIC-3 304) | 24 |
| Automatisation (RHCE) | 22 |

## Conseils de préparation

1. **Lisez le référentiel officiel** et cochez chaque objectif : « je l'ai fait dans le labo X » ou « à travailler ».
2. Les examens **pratiques** (RHCSA, LFCS, CKA) se jouent sur la **rapidité et l'aisance au clavier** : refaites les labos sans la solution, chronométrés ; maîtrisez `man`, `--help`, `/usr/share/doc`.
3. Les examens **à questions** (LPIC, Linux+) demandent de la précision sur les **options** et les **fichiers de configuration** : utilisez les aide-mémoire ([cheatsheets/](cheatsheets/01-essentiel.md)) et le [QCM](qcm-final.md).
4. Travaillez sur **les deux familles** (Debian/Ubuntu et Red Hat) : les équivalences sont dans le module 08 et dans le tableau ci-dessus.
5. Prévoyez des **examens blancs** et analysez vos erreurs par domaine.
6. Constituez un **dossier de preuves** (dépôt git avec vos scripts, playbooks, runbooks) pour vos entretiens.
