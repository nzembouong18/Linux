# Environnement de laboratoire

Les labos modifient des fichiers, créent des comptes, montent des images disque, des réseaux virtuels et des services. **Travaillez toujours dans un environnement jetable**, jamais sur votre poste personnel ni sur un serveur de production.

## Quelle option choisir ?

| Option | Mise en place | Labos couverts | Forces | Limites |
|--------|---------------|----------------|--------|---------|
| **A. Docker Compose** (recommandé) | 2 min | **tous** (conteneur privilégié avec systemd) | rapide, jetable, reproductible | pas de vrai boot/GRUB ; cgroups v2 dépendent de l'hôte ; ne pas exposer |
| **B. Vagrant (VM)** | 10 min | **tous**, y compris disques additionnels réels, boot, systemd réel | le plus fidèle à la réalité | plus lourd (4 Go RAM) |
| **C. WSL2 (Windows)** | 5 min | 01-12, 14 (systemd activable), 15, 18-19, 22-25 | pratique sur poste Windows | stockage/noyau limités |
| **D. VM manuelle** (VirtualBox, KVM, VMware) | 20 min | tous | contrôle total | à configurer |
| **E. Cloud** (instance Ubuntu 24.04 jetable) | 5 min | tous sauf modules matériel | vrai réseau, IP publique | coût, ne pas laisser tourner |

## Option A — Docker Compose

Prérequis : Docker Engine ≥ 24 ou Docker Desktop, plugin Compose v2.

```bash
git clone https://github.com/nzembouong18/Linux.git && cd Linux
docker compose up -d --build            # construit l'image (≈ 5 min la 1re fois) et démarre systemd
docker compose exec -u student lab bash # shell dans le labo (utilisateur « student », sudo sans mot de passe)
student@lab:/opt/linux-training$ ./lab list
student@lab:/opt/linux-training$ ./lab setup 01 && cat modules/01-introduction/LAB.md
docker compose down -v                  # tout supprimer
```

- Le dépôt est **monté** dans `/opt/linux-training` : vous pouvez l'éditer depuis votre machine.
- Les labos s'installent dans `~/labs/NN` de l'utilisateur `student` (volume `lab-home`).
- `privileged: true` est requis pour les modules 13 (loop, LVM), 17 (namespaces), 20 (conteneurs), 14 (systemd). **Ne lancez pas ce conteneur sur un serveur exposé.**
- Docker Desktop (macOS/Windows) : si `cgroup: host` pose problème, activez cgroups v2 ou utilisez l'option B.

## Option B — Vagrant

Prérequis : Vagrant ≥ 2.3 + VirtualBox ≥ 7 (ou libvirt).

```bash
vagrant up                    # VM « lab » (192.168.56.10, 2 disques de 1 Go) + VM « srv1 » (192.168.56.11)
vagrant ssh lab
cd /vagrant && ./lab list
vagrant destroy -f            # tout supprimer
```
La VM `lab` sert aux modules 13 (disques additionnels `/dev/sdb`, `/dev/sdc`), 21 (GRUB réel), 17 ; `srv1` est la cible des exercices SSH/rsync/réseau « avancés » (« pour aller plus loin »).

## Option C — WSL2

```powershell
wsl --install -d Ubuntu-24.04
```
Dans Ubuntu : activer systemd (`/etc/wsl.conf` : `[boot]\nsystemd=true`, puis `wsl --shutdown`), installer les paquets de la section ci-dessous, cloner le dépôt **dans le système de fichiers Linux** (`~`, pas `/mnt/c`). Les labos nécessitant `loop`, `LVM` ou les namespaces peuvent être ignorés (`skip`) : utilisez alors A ou B pour ceux-là.

## Paquets nécessaires (VM manuelle / WSL2)

```bash
sudo apt update && sudo apt install -y \
  bash-completion vim nano tree file bc tmux acl attr jq rsync git shellcheck \
  iproute2 iputils-ping dnsutils netcat-openbsd curl tcpdump nftables traceroute mtr-tiny iperf3 \
  procps psmisc lsof htop strace sysstat stress-ng cron logrotate rsyslog \
  lvm2 parted gdisk xfsprogs e2fsprogs dosfstools mdadm cryptsetup-bin \
  bzip2 xz-utils zstd zip unzip gnupg openssl openssh-server openssh-client \
  python3 python3-yaml python3-jmespath nginx-light apache2-utils haproxy keepalived busybox-static \
  prometheus prometheus-node-exporter ansible-core yamllint
sudo systemctl disable --now nginx haproxy keepalived prometheus prometheus-node-exporter ssh
```
(Les services sont désactivés : les labos lancent leurs propres instances sur des ports libres.)

## Utilisation du lanceur `./lab`

```bash
./lab list              # modules
./lab setup  NN         # prépare ~/labs/NN
./lab check  NN         # vérifie votre travail (coches vertes ✔ / rouges ✘)
./lab solve  NN         # applique la solution de référence
./lab reset  NN         # supprime le labo et ses effets (comptes, montages, processus…)
./lab demo   NN         # démonstration du formateur (DEMO_FAST=1 : sans pauses)
./lab doc    NN         # chemins du cours et de l'énoncé
LAB_ROOT=/tmp/labs ./lab setup 05      # changer le dossier de travail
NO_COLOR=1 ./lab check 05              # sans couleurs
```

Codes de sortie : `0` réussite · `1` des points à corriger · `77` labo ignoré (prérequis absent : root, systemd, loop, namespaces…).

## Dépannage

| Problème | Cause / solution |
|----------|------------------|
| `Labo non initialisé` | lancer d'abord `./lab setup NN` |
| `Ce labo nécessite root/sudo` | utiliser `student` (sudo sans mot de passe) ou `sudo ./lab …` |
| `nécessite les périphériques loop / namespaces / systemd` | environnement non privilégié : utiliser l'option A (compose privilégié) ou B (VM) |
| `⊘ … (ignoré : non supporté ici)` | une vérification dépend du noyau (ex. device-mapper pour LVM, cgroups v2) : elle est ignorée, le reste compte |
| `address already in use` | un ancien processus de labo traîne : `./lab reset NN` |
| `Permission denied` sur `~/labs` | ne pas lancer les labos avec un `HOME` en lecture seule |
| La couleur casse les journaux | `NO_COLOR=1` |
| Docker : `cgroup: host` refusé | Docker Desktop ancien → mettre à jour, ou option B |

## Sécurité et hygiène

- Ne réutilisez **jamais** les mots de passe de l'environnement (`student:formation`, `.vault_pass`) ailleurs.
- Ne publiez pas le conteneur de labo sur Internet.
- Les comptes et objets créés par les labos portent les préfixes `lab_`, `lab17-`, `labvg`… ; `./lab reset NN` les supprime.
