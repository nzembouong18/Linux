# Parcours de formation et planification

La formation compte **25 modules** répartis en **4 niveaux**, soit environ **130 à 150 heures** (cours + labos + démonstrations + projet). Chaque module contient : un **cours**, un **labo vérifié automatiquement**, une **démonstration** pour le formateur et un **quiz**.

## Vue d'ensemble

| Niveau | Modules | Durée indicative | Compétence visée |
|--------|---------|:----------------:|------------------|
| **1 — Débutant** (Fondations) | 01 → 06 | ≈ 20 h | Utiliser Linux en ligne de commande sans crainte |
| **2 — Intermédiaire** (Administration) | 07 → 15 | ≈ 45 h | Administrer un serveur : processus, paquets, scripts, réseau, SSH, stockage, services, sauvegardes |
| **3 — Avancé** (Expertise) | 16 → 21 | ≈ 40 h | Sécuriser, diagnostiquer, déployer web/conteneurs, comprendre noyau et démarrage |
| **4 — Professionnel** (Production) | 22 → 25 | ≈ 28 h + projet | Automatiser, superviser, rendre résilient, livrer en production |

## Détail des modules

| N° | Module | Niveau | Durée | Labo (vérification) |
|----|--------|--------|:-----:|---------------------|
| 01 | [Introduction à Linux et mise en place du labo](../modules/01-introduction/README.md) | Débutant | 2 h | fiche d'identité du système |
| 02 | [Terminal, shell et navigation](../modules/02-terminal-et-navigation/README.md) | Débutant | 3 h | chasse au trésor dans l'arborescence |
| 03 | [Fichiers et répertoires](../modules/03-fichiers-et-repertoires/README.md) | Débutant | 3 h | ranger un dossier « vrac » |
| 04 | [Lire et éditer (cat, less, nano, vim)](../modules/04-lecture-et-edition/README.md) | Débutant | 3 h | journaux et fichier de configuration |
| 05 | [Redirections, pipes et filtres](../modules/05-redirections-pipes-filtres/README.md) | Débutant | 4 h | analyse d'un journal d'accès |
| 06 | [Utilisateurs et permissions](../modules/06-utilisateurs-et-permissions/README.md) | Débutant | 4 h | espace de travail partagé sécurisé |
| 07 | [Processus et signaux](../modules/07-processus-et-signaux/README.md) | Intermédiaire | 3 h | piloter des processus |
| 08 | [Gestion des paquets](../modules/08-gestion-des-paquets/README.md) | Intermédiaire | 3 h | construire et verrouiller un `.deb` |
| 09 | [Scripting Bash](../modules/09-scripting-bash/README.md) | Intermédiaire | 6 h | 5 scripts testés |
| 10 | [Texte avancé : regex, sed, awk, jq](../modules/10-texte-avance/README.md) | Intermédiaire | 5 h | atelier de traitement de données |
| 11 | [Réseau : fondamentaux](../modules/11-reseau-fondamentaux/README.md) | Intermédiaire | 5 h | calculs CIDR + enquête locale |
| 12 | [SSH et transferts](../modules/12-ssh-et-transferts/README.md) | Intermédiaire | 4 h | clés, config, rsync, tunnel |
| 13 | [Stockage et systèmes de fichiers](../modules/13-stockage-et-systemes-de-fichiers/README.md) | Intermédiaire | 6 h | images, fstab, LVM |
| 14 | [systemd, services, cron et timers](../modules/14-systemd-et-services/README.md) | Intermédiaire | 6 h | service, timer, cron |
| 15 | [Journaux, archivage et sauvegardes](../modules/15-journaux-et-archivage/README.md) | Intermédiaire | 5 h | tar, logrotate, rsync incrémental |
| 16 | [Sécurité et durcissement](../modules/16-securite-et-durcissement/README.md) | Avancé | 8 h | audit et durcissement d'un serveur |
| 17 | [Réseau avancé](../modules/17-reseau-avance/README.md) | Avancé | 8 h | routeur, NAT et capture (namespaces) |
| 18 | [Performance et dépannage](../modules/18-performance-et-depannage/README.md) | Avancé | 7 h | enquête sur 5 processus coupables |
| 19 | [Serveurs web et reverse proxy](../modules/19-serveurs-web-et-services/README.md) | Avancé | 7 h | passerelle nginx |
| 20 | [Conteneurs et namespaces](../modules/20-conteneurs-et-namespaces/README.md) | Avancé | 8 h | conteneur « fait main », Dockerfile |
| 21 | [Noyau, démarrage et récupération](../modules/21-noyau-et-demarrage/README.md) | Avancé | 6 h | GRUB, modules, udev, analyse de boot |
| 22 | [Automatisation et IaC](../modules/22-automatisation-iac/README.md) | Professionnel | 7 h | projet Ansible idempotent |
| 23 | [Supervision et observabilité](../modules/23-supervision-et-observabilite/README.md) | Professionnel | 7 h | exporter, plugin, alertes, SLO |
| 24 | [Haute disponibilité et PRA](../modules/24-haute-disponibilite-et-pra/README.md) | Professionnel | 7 h | restauration vérifiée, bascule |
| 25 | [Projet final](../modules/25-projet-final/README.md) | Professionnel | 12-16 h | mise en production complète |

## Dépendances entre modules

```text
01 ─ 02 ─ 03 ─ 04 ─ 05 ─ 06 ───────────────────────────────┐
                │      │    │                               │
                │      │    └─ 07 ─ 08                      │
                │      └────── 09 ─ 10                      │
                │                │                          │
                └─ 11 ─ 12 ──────┤                          │
                      │          │                          │
        13 ─ 14 ─ 15 ┘          ...                         │
         │    │    │                                         │
         └────┴────┴─ 16 ─ 17 ─ 18 ─ 19 ─ 20 ─ 21           │
                                     │                      │
                          22 ─ 23 ─ 24 ─────────────── 25 ──┘
```
Règle générale : suivre l'ordre numérique. Un module peut être ignoré si ses **objectifs** (en tête de chaque cours) sont déjà acquis : testez-vous avec son **quiz** et son **labo**.

## Parcours spécialisés

| Profil | Modules prioritaires | Pour aller plus loin |
|--------|----------------------|----------------------|
| **Administrateur système junior** | 01-15, 16 (début), 18 | 19, 22 |
| **DevOps / SRE** | 01-06, 09-12, 14, 17-20, 22-25 | Kubernetes, Terraform |
| **Sécurité (Blue Team)** | 01-06, 09-12, 14-17, 21, 23 | SELinux, forensics, SIEM |
| **Développeur qui déploie** | 01-06, 09, 11-12, 14, 19-20, 22 | CI/CD |
| **Préparation LPIC-1 / RHCSA** | voir [certifications.md](certifications.md) | |

## Rythmes proposés

### Intensif — 4 semaines à plein temps (35 h/sem.)
| Semaine | Contenu |
|---------|---------|
| 1 | Modules 01 → 08 |
| 2 | Modules 09 → 15 |
| 3 | Modules 16 → 21 |
| 4 | Modules 22 → 24 + projet final (25) + soutenance |

### Pour salariés — 12 semaines, 2 soirées de 3 h + 1 samedi de 4 h
| Semaines | Contenu |
|----------|---------|
| 1-2 | 01 → 03 |
| 3-4 | 04 → 06 |
| 5 | 07 → 08 |
| 6 | 09 → 10 |
| 7 | 11 → 12 |
| 8 | 13 → 14 |
| 9 | 15 → 16 |
| 10 | 17 → 19 |
| 11 | 20 → 22 |
| 12 | 23 → 24, début du projet |
| +2 | projet final et soutenance |

### Autoformation — 1 module par semaine, 6 à 8 h
Lire le cours (2 h) → rejouer la démonstration en la commentant (1 h) → labo (2-3 h) → quiz et fiche de synthèse (1 h).

## Méthode pédagogique d'un module

1. **Comprendre** (cours) – lire en testant chaque commande dans le terminal ;
2. **Voir** (démo) – `./lab demo NN` : le formateur (ou vous) commente chaque commande ;
3. **Faire** (labo) – `./lab setup NN`, travailler, `./lab check NN` jusqu'à 100 % ;
4. **Consolider** (quiz, « pour aller plus loin ») ;
5. **Comparer** – `./lab solve NN` *après* votre tentative, lire la solution de référence ;
6. **Réinitialiser** – `./lab reset NN`.

Tenez un **journal d'apprentissage** (un fichier Markdown par module : ce que j'ai compris, mes erreurs, mes commandes utiles) et un dépôt git personnel de **scripts et configurations**.
