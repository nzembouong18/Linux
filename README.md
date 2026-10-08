# 🐧 Formation Linux complète — du débutant au professionnel

[![CI](https://github.com/nzembouong18/Linux/actions/workflows/ci.yml/badge.svg)](https://github.com/nzembouong18/Linux/actions/workflows/ci.yml)
![Modules](https://img.shields.io/badge/modules-25-blue)
![Labos](https://img.shields.io/badge/labos%20v%C3%A9rifi%C3%A9s-25-brightgreen)
![Licence](https://img.shields.io/badge/licence-MIT-lightgrey)

Une formation **complète, progressive et pratique** à Linux : **25 modules**, **~140 heures**, avec pour chaque module un **cours**, un **labo vérifié automatiquement**, une **démonstration** pour le formateur, un **quiz** et un **projet final** de mise en production.

> **Principe** : on apprend Linux en le **faisant**. Chaque labo se prépare avec `./lab setup`, se corrige avec `./lab check` (coches ✔/✘ immédiates) et dispose d'une solution de référence (`./lab solve`) — le tout testé en continu par la CI.

---

## Sommaire

1. [Ce que vous allez apprendre](#ce-que-vous-allez-apprendre)
2. [Démarrage rapide](#démarrage-rapide)
3. [Les 25 modules](#les-25-modules)
4. [Comment fonctionne un module](#comment-fonctionne-un-module)
5. [Le lanceur `./lab`](#le-lanceur-lab)
6. [Structure du dépôt](#structure-du-dépôt)
7. [Documentation complémentaire](#documentation-complémentaire)
8. [Évaluation et certifications](#évaluation-et-certifications)
9. [Contribuer](#contribuer)
10. [Licence](#licence)

---

## Ce que vous allez apprendre

| Niveau | Vous saurez… |
|--------|---------------|
| 🌱 **1 — Débutant** (modules 01-06) | naviguer, manipuler fichiers et texte, chaîner des commandes avec pipes et redirections, gérer utilisateurs et permissions |
| 🔧 **2 — Intermédiaire** (07-15) | piloter processus et signaux, gérer paquets, **écrire des scripts Bash robustes**, maîtriser `sed`/`awk`/`jq`, configurer réseau, **SSH**, stockage (**LVM**), **systemd**, cron/timers, journaux et **sauvegardes** |
| 🛡️ **3 — Avancé** (16-21) | **sécuriser** un serveur (pare-feu, SELinux/AppArmor, audit), construire un **routeur Linux** (namespaces, NAT), **diagnostiquer** les performances, déployer **nginx/reverse proxy**, comprendre les **conteneurs** de l'intérieur, maîtriser **noyau, démarrage et récupération** |
| 🚀 **4 — Professionnel** (22-25) | **automatiser** avec Ansible (idempotence, Vault), **superviser** (Prometheus, SLO), concevoir **haute disponibilité et PRA**, **livrer en production** un service complet |

Public : étudiants, techniciens, développeurs, futurs administrateurs système / DevOps / SRE, préparation à **LPIC, RHCSA, LFCS, Linux+** (voir [certifications](docs/certifications.md)).

Prérequis : savoir utiliser un ordinateur et installer un logiciel. Aucune connaissance de Linux n'est nécessaire.

---

## Démarrage rapide

### Option A — Docker Compose (recommandé, 2 minutes)

```bash
git clone https://github.com/nzembouong18/Linux.git && cd Linux
docker compose up -d --build                  # Ubuntu 24.04 + systemd + tous les outils
docker compose exec -u student lab bash       # shell dans le laboratoire (jetable)
./lab list                                    # les 25 modules
./lab setup 01 && cat modules/01-introduction/LAB.md
```

### Option B — Machine virtuelle (la plus fidèle : disques, boot, systemd réels)

```bash
vagrant up && vagrant ssh lab && cd /vagrant && ./lab list
```

### Option C — Votre propre Ubuntu 24.04 / WSL2

Voir [docs/lab-environment.md](docs/lab-environment.md) (liste des paquets, WSL2, dépannage).

> ⚠️ **Travaillez toujours dans un environnement jetable** : les labos créent des comptes, montent des images disque, manipulent le réseau et les services.

---

## Les 25 modules

### 🌱 Niveau 1 — Débutant (≈ 20 h)

| N° | Module | Labo |
|----|--------|------|
| 01 | [Introduction à Linux et mise en place du labo](modules/01-introduction/README.md) | fiche d'identité d'un système |
| 02 | [Terminal, shell et navigation](modules/02-terminal-et-navigation/README.md) | chasse au trésor dans l'arborescence |
| 03 | [Fichiers et répertoires](modules/03-fichiers-et-repertoires/README.md) | ranger un dossier « vrac » |
| 04 | [Lire et éditer (cat, less, nano, vim)](modules/04-lecture-et-edition/README.md) | journaux et fichier de configuration |
| 05 | [Redirections, pipes et filtres](modules/05-redirections-pipes-filtres/README.md) | analyse d'un journal d'accès |
| 06 | [Utilisateurs et permissions](modules/06-utilisateurs-et-permissions/README.md) | espace de travail partagé sécurisé |

### 🔧 Niveau 2 — Intermédiaire (≈ 45 h)

| N° | Module | Labo |
|----|--------|------|
| 07 | [Processus et signaux](modules/07-processus-et-signaux/README.md) | piloter démon et processus récalcitrant |
| 08 | [Gestion des paquets et dépôts](modules/08-gestion-des-paquets/README.md) | construire, installer, verrouiller un `.deb` |
| 09 | [Scripting Bash](modules/09-scripting-bash/README.md) | 5 scripts testés automatiquement |
| 10 | [Texte avancé : regex, sed, awk, jq](modules/10-texte-avance/README.md) | atelier de traitement de données |
| 11 | [Réseau : fondamentaux](modules/11-reseau-fondamentaux/README.md) | calculs CIDR + enquête sur un service |
| 12 | [SSH, clés, tunnels et transferts](modules/12-ssh-et-transferts/README.md) | serveur SSH de labo, rsync, tunnel |
| 13 | [Stockage, fstab, LVM, RAID, LUKS](modules/13-stockage-et-systemes-de-fichiers/README.md) | images disque, montages, LVM |
| 14 | [systemd, services, cron et timers](modules/14-systemd-et-services/README.md) | service durci + timer + cron |
| 15 | [Journaux, archivage et sauvegardes](modules/15-journaux-et-archivage/README.md) | tar, logrotate, rsync incrémental |

### 🛡️ Niveau 3 — Avancé (≈ 40 h)

| N° | Module | Labo |
|----|--------|------|
| 16 | [Sécurité et durcissement](modules/16-securite-et-durcissement/README.md) | audit et durcissement d'un serveur |
| 17 | [Réseau avancé : namespaces, NAT, tcpdump](modules/17-reseau-avance/README.md) | routeur + pare-feu + NAT virtuels |
| 18 | [Performance et dépannage](modules/18-performance-et-depannage/README.md) | enquête sur 5 processus coupables |
| 19 | [Serveurs web, reverse proxy, TLS](modules/19-serveurs-web-et-services/README.md) | passerelle nginx complète |
| 20 | [Conteneurs : namespaces, cgroups, Docker](modules/20-conteneurs-et-namespaces/README.md) | mini-conteneur fait main + Dockerfile |
| 21 | [Noyau, démarrage et récupération](modules/21-noyau-et-demarrage/README.md) | GRUB, modules, udev, analyse de boot |

### 🚀 Niveau 4 — Professionnel (≈ 28 h + projet)

| N° | Module | Labo |
|----|--------|------|
| 22 | [Automatisation et IaC : Ansible, cloud-init, Terraform](modules/22-automatisation-iac/README.md) | projet Ansible idempotent avec Vault |
| 23 | [Supervision et observabilité](modules/23-supervision-et-observabilite/README.md) | exporter, plugin Nagios, alertes, SLO |
| 24 | [Haute disponibilité, sauvegardes, PRA](modules/24-haute-disponibilite-et-pra/README.md) | restauration vérifiée, bascule, keepalived |
| 25 | [**Projet final** : mise en production](modules/25-projet-final/README.md) | livrable complet + soutenance |

Le détail (durées, dépendances, rythmes de 4 à 12 semaines, parcours par profil) est dans [docs/parcours.md](docs/parcours.md).

---

## Comment fonctionne un module

```text
modules/NN-nom/
├── README.md   📖 le cours : objectifs, explications, exemples, résumé, quiz (réponses repliées)
├── LAB.md      🧪 l'énoncé du labo : contexte, tâches, indices (repliés), solution (repliée)
├── lab.sh      ✅ prépare le labo, VÉRIFIE votre travail, applique la solution de référence
└── demo.sh     🎬 démonstration commentée pour le formateur (rejouable, enregistrable)
```

**Démarche conseillée** : lire le cours en testant → regarder la démo (`./lab demo NN`) → faire le labo → `./lab check NN` jusqu'au 100 % → quiz → comparer avec `./lab solve NN` → `./lab reset NN`.

Exemple de correction :

```text
$ ./lab check 05
Vérification du labo 05
  ✔ sortie.txt contient le listing de /etc
  ✔ erreurs.txt contient uniquement l'erreur
  ✘ top_ips.txt (3 premières IP)
  ...
Résultat : 9/10 — 1 point(s) à corriger.
```

---

## Le lanceur `./lab`

```bash
./lab list              # liste des modules
./lab setup  NN         # prépare ~/labs/NN
./lab check  NN         # vérifie votre travail
./lab solve  NN         # applique la solution de référence
./lab reset  NN         # nettoie (fichiers, comptes, montages, processus…)
./lab demo   NN         # lance la démonstration (DEMO_FAST=1 : sans pauses)
./lab doc    NN         # chemins du cours et de l'énoncé
```

Un labo qui nécessite un prérequis absent (root, systemd, périphériques loop, namespaces…) se termine avec le code `77` (ignoré) ; une vérification dépendant du noyau est marquée `⊘` sans pénaliser le reste.

---

## Structure du dépôt

```text
.
├── README.md               ← vous êtes ici
├── lab                     lanceur des labos et démos
├── modules/                les 25 modules (cours + labos + démos)
│   └── 25-projet-final/    cahier des charges, grille, solution de référence
├── scripts/
│   ├── lib.sh              bibliothèque des labos (assertions, setup/check/solve/reset)
│   ├── demo-lib.sh         moteur de démonstration (frappe simulée, pauses)
│   ├── validate.sh         teste TOUS les labos et démos (utilisé par la CI)
│   └── check-links.sh      vérifie les liens Markdown relatifs
├── docs/                   parcours, guide formateur, évaluation, QCM, aide-mémoire, glossaire…
│   └── cheatsheets/        3 aide-mémoire (essentiel, administration, avancé/pro)
├── Dockerfile · docker-compose.yml · Vagrantfile     environnements de labo
├── Makefile                `make help`, `make validate`, `make lint`…
└── .github/workflows/ci.yml   intégration continue
```

---

## Documentation complémentaire

| Document | Contenu |
|----------|---------|
| [docs/parcours.md](docs/parcours.md) | plan détaillé, durées, rythmes (intensif, salarié, autoformation), parcours par profil |
| [docs/lab-environment.md](docs/lab-environment.md) | Docker, Vagrant, WSL2, VM, dépannage |
| [docs/formateur.md](docs/formateur.md) | guide d'animation, pièges par module, déroulé type |
| [docs/evaluation.md](docs/evaluation.md) | barème, badges, relevé de notes |
| [docs/qcm-final.md](docs/qcm-final.md) | QCM de 60 questions corrigées |
| [docs/cheatsheets/](docs/cheatsheets/01-essentiel.md) | aide-mémoire imprimables |
| [docs/glossaire.md](docs/glossaire.md) | ~80 termes |
| [docs/certifications.md](docs/certifications.md) | correspondance avec LPIC, RHCSA, LFCS, Linux+ |
| [docs/ressources.md](docs/ressources.md) | livres, sites, plateformes, outils, veille |

---

## Évaluation et certifications

- **Contrôle continu** : chaque labo se note automatiquement (`./lab check NN`).
- **QCM final** de 60 questions ([qcm-final.md](docs/qcm-final.md)).
- **Projet final** noté sur [grille](modules/25-projet-final/grille-evaluation.md) (automatique + revue de code + documentation + soutenance chronométrée).
- Préparation aux certifications : [correspondance détaillée](docs/certifications.md).

---

## Qualité : tout est testé

La commande `make validate` (et la CI GitHub) exécute, pour **chacun des 25 modules** :

1. `setup` du labo → 2. `check` (**doit échouer** : le labo n'est pas trivial) → 3. `solve` → 4. `check` (**doit réussir à 100 %**) → 5. `demo` (sans erreur) → 6. `reset` (nettoyage).

Les scripts passent `shellcheck` (`make lint`) et les liens Markdown sont vérifiés (`make links`).

---

## Contribuer

Les contributions sont les bienvenues (corrections, nouveaux exercices, traductions) : voir [CONTRIBUTING.md](CONTRIBUTING.md). Avant une proposition : `make lint links validate-NN`.

## Licence

[MIT](LICENSE) — réutilisation libre, y compris en entreprise et en formation, avec mention de la licence.
