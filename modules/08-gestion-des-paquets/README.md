# Module 08 — Gestion des paquets et des dépôts logiciels

> **Niveau** : Intermédiaire | **Durée** : 3 h (1 h 30 cours + 1 h 30 labo) | **Prérequis** : modules 02–06
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer le rôle d'un **paquet**, d'un **dépôt** et d'un **gestionnaire de dépendances** ;
> - installer, mettre à jour, interroger et supprimer des logiciels avec `apt`/`dpkg` **et** `dnf`/`rpm` ;
> - configurer des dépôts tiers de façon sûre (clés GPG) ;
> - verrouiller des versions et automatiser les mises à jour de sécurité ;
> - **construire** un paquet `.deb` simple ;
> - connaître les alternatives : snap, flatpak, compilation depuis les sources.

---

## 1. Pourquoi des paquets ?

Un **paquet** est une archive contenant : les fichiers à installer, des **métadonnées** (nom, version, dépendances, description), des **scripts** d'installation (`preinst`, `postinst`, `prerm`, `postrm`) et une **signature**.

Le **gestionnaire de paquets** :

1. résout les **dépendances** automatiquement ;
2. vérifie l'**authenticité** (signatures GPG) et l'**intégrité** ;
3. garde une **base de données** de ce qui est installé (donc désinstallation propre, mise à jour, audit) ;
4. récupère les mises à jour de **sécurité** depuis des **dépôts** (miroirs).

```text
           ┌──────────────┐  apt update   ┌────────────┐
 Dépôt  ─► │ index Packages│ ───────────► │ cache local │  /var/lib/apt/lists
 (miroir)  └──────────────┘               └─────┬──────┘
     │   .deb signés                            │ apt install nginx
     └──────────────► /var/cache/apt/archives ◄─┘ (résolution des dépendances)
                              │ dpkg -i
                              ▼
                     fichiers installés + base /var/lib/dpkg/status
```

## 2. Deux familles

| | Debian / Ubuntu | Red Hat / Rocky / Alma / Fedora |
|---|---|---|
| Format | `.deb` | `.rpm` |
| Outil bas niveau (local, sans dépendances) | `dpkg` | `rpm` |
| Outil haut niveau (dépôts, dépendances) | `apt` (`apt-get`, `apt-cache`) | `dnf` (anciennement `yum`) |
| Dépôts | `/etc/apt/sources.list`, `/etc/apt/sources.list.d/` | `/etc/yum.repos.d/*.repo` |
| Sécurité obligatoire | Release signé (InRelease) | `gpgcheck=1` |

### Équivalences à connaître par cœur

| Action | apt (Debian/Ubuntu) | dnf (RHEL-like) |
|--------|---------------------|-----------------|
| Rafraîchir les index | `apt update` | (automatique) `dnf makecache` |
| Mettre à jour tout | `apt upgrade` / `apt full-upgrade` | `dnf upgrade` |
| Installer | `apt install nginx` | `dnf install nginx` |
| Supprimer | `apt remove nginx` | `dnf remove nginx` |
| Supprimer + config | `apt purge nginx` | — |
| Nettoyer orphelins | `apt autoremove` | `dnf autoremove` |
| Chercher | `apt search mot` | `dnf search mot` |
| Détails d'un paquet | `apt show nginx` | `dnf info nginx` |
| Liste des installés | `apt list --installed` / `dpkg -l` | `dnf list installed` / `rpm -qa` |
| Qui fournit ce fichier ? | `dpkg -S /usr/bin/ssh` / `apt-file search` | `rpm -qf /usr/bin/ssh` / `dnf provides */ssh` |
| Fichiers d'un paquet | `dpkg -L nginx` | `rpm -ql nginx` |
| Installer un fichier local | `apt install ./x.deb` / `dpkg -i x.deb` | `dnf install ./x.rpm` / `rpm -i x.rpm` |
| Dépendances inverses | `apt rdepends nginx` | `dnf repoquery --whatrequires nginx` |
| Mises à jour dispo | `apt list --upgradable` | `dnf check-update` |
| Verrouiller | `apt-mark hold nginx` | `dnf versionlock add nginx` |
| Historique | `/var/log/apt/history.log` | `dnf history` (+ `dnf history undo N`) |

## 3. APT au quotidien

```bash
sudo apt update                         # télécharge les index des dépôts (ne modifie PAS le système)
apt list --upgradable                   # ce qui peut être mis à jour
sudo apt upgrade                        # met à jour sans jamais supprimer de paquets
sudo apt full-upgrade                   # accepte d'ajouter/supprimer des paquets (changements de noyau…)
sudo apt install nginx curl             # installe (+ dépendances)
sudo apt install -y --no-install-recommends vim-tiny      # automatisation / images minimales
sudo apt install nginx=1.24.0-2ubuntu7  # version précise
sudo apt remove nginx                   # supprime les binaires, garde /etc
sudo apt purge nginx                    # supprime aussi la configuration
sudo apt autoremove --purge             # retire les dépendances devenues inutiles
sudo apt clean                          # vide le cache /var/cache/apt/archives
apt search "web server"                 # recherche
apt show nginx                          # description, dépendances, taille
apt policy nginx                        # versions installée / candidate / dépôt d'origine
apt depends nginx ; apt rdepends nginx  # dépendances directes / inverses
apt-get -s install nginx                # simulation (-s) : que ferait l'installation ?
```

`apt` est l'interface **interactive** (barre de progression, couleurs) ; `apt-get` / `apt-cache` ont une sortie stable pour les **scripts**.

### Dans un script ou une image de conteneur

```bash
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
```

### Erreur classique : « Could not get lock /var/lib/dpkg/lock-frontend »

Un autre `apt` (ou `unattended-upgrades`) tourne. Attendez, ou identifiez-le : `ps aux | grep -E 'apt|dpkg'`. **Ne supprimez pas les verrous à la main** sauf certitude. Si une opération a été interrompue : `sudo dpkg --configure -a` puis `sudo apt -f install`.

## 4. dpkg : le niveau bas

```bash
dpkg -l | grep nginx             # ii = installé · rc = supprimé mais config restante
dpkg -s nginx                    # état détaillé d'un paquet
dpkg -L nginx                    # fichiers installés par le paquet
dpkg -S /usr/sbin/nginx          # quel paquet a installé ce fichier ?
sudo dpkg -i paquet.deb          # installe un .deb local (sans résoudre les dépendances)
sudo apt -f install              # termine / répare les dépendances manquantes
sudo dpkg -r paquet ; sudo dpkg -P paquet     # remove / purge
dpkg-deb -I paquet.deb           # métadonnées d'un .deb
dpkg-deb -c paquet.deb           # contenu d'un .deb
debsums -c                       # fichiers modifiés depuis l'installation (paquet debsums)
dpkg-query -W -f='${Package} ${Version}\n' 'linux-image-*'
```

## 5. Les dépôts

### Configuration Ubuntu 24.04 / Debian 12+ (format deb822)

`/etc/apt/sources.list.d/ubuntu.sources` :

```text
Types: deb
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

Composants Ubuntu : **main** (supporté, libre) · **restricted** (pilotes propriétaires) · **universe** (communauté) · **multiverse** (non libre). Suites : `noble` (version initiale), `-security`, `-updates`, `-backports`.

### Ajouter un dépôt tiers *proprement*

```bash
# 1) récupérer la clé et la ranger dans un trousseau dédié (PAS apt-key, déprécié)
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://example.org/repo/key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/example.gpg

# 2) déclarer le dépôt en limitant la confiance à cette clé
echo "deb [signed-by=/etc/apt/keyrings/example.gpg] https://example.org/repo stable main" \
  | sudo tee /etc/apt/sources.list.d/example.list

sudo apt update && apt policy exemple-paquet
```

> 🔐 Un dépôt tiers peut remplacer n'importe quel paquet système : n'ajoutez que des sources de confiance, avec `signed-by`. Évitez `curl … | sudo bash`.

PPA Ubuntu : `sudo add-apt-repository ppa:nom/ppa` (même vigilance). Épinglage de priorités : `/etc/apt/preferences.d/` (*pinning*).

### Red Hat : fichier `.repo`

```ini
# /etc/yum.repos.d/example.repo
[example]
name=Example
baseurl=https://example.org/el9/$basearch
enabled=1
gpgcheck=1
gpgkey=https://example.org/RPM-GPG-KEY
```
`dnf repolist`, `dnf config-manager --set-enabled crb`, EPEL : `dnf install epel-release`.

## 6. Verrouiller, simuler, mettre à jour automatiquement

```bash
sudo apt-mark hold nginx           # empêche la mise à jour de ce paquet
apt-mark showhold ; sudo apt-mark unhold nginx
apt-get -s upgrade                 # simulation avant la vraie mise à jour
```

**Mises à jour de sécurité automatiques** (Debian/Ubuntu) :

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades
# APT::Periodic::Update-Package-Lists "1";
# APT::Periodic::Unattended-Upgrade "1";
```

Après mise à jour d'une bibliothèque, des services continuent d'utiliser l'ancienne version en mémoire : `sudo needrestart` (ou `checkrestart`). Un nouveau noyau nécessite un **redémarrage** : `/var/run/reboot-required`.

Red Hat : `dnf-automatic` (timer systemd). Bonnes pratiques : tester en préproduction, planifier des fenêtres de maintenance, conserver un instantané/une sauvegarde.

## 7. Construire un paquet `.deb` minimal

Structure :

```text
monpaquet/
├── DEBIAN/
│   └── control          ← métadonnées obligatoires
└── usr/local/bin/
    └── bonjour          ← les fichiers, à leur chemin final
```

`DEBIAN/control` :

```text
Package: monpaquet
Version: 1.0
Section: utils
Priority: optional
Architecture: all
Maintainer: Votre Nom <vous@example.org>
Description: Mon premier paquet
 Ligne(s) suivantes indentées d'un espace : description longue.
```

```bash
chmod 755 monpaquet/usr/local/bin/bonjour
dpkg-deb --build --root-owner-group monpaquet monpaquet_1.0_all.deb
dpkg-deb -I monpaquet_1.0_all.deb ; dpkg-deb -c monpaquet_1.0_all.deb
sudo apt install ./monpaquet_1.0_all.deb       # résout les dépendances si besoin
```

Pour un vrai paquet distribuable : `debhelper`, `dpkg-buildpackage`, `lintian`, dépôt avec `reprepro`/`aptly`. Côté RPM : fichier `.spec`, `rpmbuild`, `rpmlint`. Pour du multi-distribution : `fpm`.

## 8. Autres moyens d'installer

| Méthode | Principe | Quand ? |
|---------|----------|---------|
| **snap** (`snap install code --classic`) | paquets autonomes confinés, mises à jour auto | logiciels récents sur Ubuntu |
| **flatpak** | idem, orienté bureau | postes de travail |
| **AppImage** | un fichier exécutable | tests, portable |
| **pip / npm / cargo / go install** | gestionnaires par langage | environnements de développement (utiliser `venv`, `pipx`) |
| **Compilation** | `./configure && make && sudo make install` (vers `/usr/local`) | dernier recours ; préférez `checkinstall` ou un vrai paquet |
| **Conteneurs** | image Docker/Podman | isolation et reproductibilité (module 20) |

Règle : **ne mélangez pas** `pip install` en root avec les paquets de la distribution (erreur « externally-managed-environment » volontaire). Utilisez `python3 -m venv` ou `pipx`.

## 9. Alpine, Arch, SUSE (pour mémoire)

| Distribution | Mise à jour des index | Installer | Chercher |
|--------------|----------------------|-----------|----------|
| Alpine | `apk update` | `apk add curl` | `apk search` |
| Arch | `pacman -Sy` | `pacman -S curl` | `pacman -Ss` |
| openSUSE | `zypper refresh` | `zypper install curl` | `zypper search` |

## 10. Dépannage

| Problème | Piste |
|----------|-------|
| `E: Unable to locate package` | `apt update` oublié, composant (universe) manquant, mauvaise suite |
| `Depends: X but it is not installable` | dépôt manquant ou conflit de versions ; `apt policy X` |
| `NO_PUBKEY ABCD…` | clé GPG du dépôt absente ; ajouter la clé via `signed-by` |
| Paquets « retenus » (`kept back`) | nouvelles dépendances : `apt full-upgrade` après simulation |
| Installation interrompue | `sudo dpkg --configure -a && sudo apt -f install` |
| Disque plein en `/var` | `apt clean`, `apt autoremove --purge`, anciens noyaux |

## 11. Résumé

- Paquet = fichiers + métadonnées + scripts + signature ; dépôt = source signée.
- `apt update` (index) puis `apt install / upgrade / full-upgrade / remove / purge / autoremove`.
- `dpkg -l / -L / -S / -s / -i` pour interroger et installer localement ; `rpm`/`dnf` côté Red Hat.
- Dépôt tiers : clé dans `/etc/apt/keyrings` + `signed-by`.
- `apt-mark hold`, `unattended-upgrades`, `needrestart`.
- Construire un `.deb` : `DEBIAN/control` + arborescence + `dpkg-deb --build`.

## 12. Quiz

1. Quelle est la différence entre `apt update` et `apt upgrade` ?
2. Comment savoir quel paquet a installé `/usr/bin/curl` ? Côté Red Hat ?
3. Quelle différence entre `remove` et `purge` ?
4. Pourquoi `apt-key` est-il déprécié et quelle est l'alternative ?
5. Comment empêcher la mise à jour de `docker-ce` ?
6. Que signifie `rc` dans `dpkg -l` ?
7. Vous installez un `.deb` avec `dpkg -i` et il manque des dépendances : que faites-vous ?
8. Quelle option rend `apt install` non interactif dans un Dockerfile ?

<details><summary>Réponses</summary>

1. `update` rafraîchit les index ; `upgrade` installe les nouvelles versions.
2. `dpkg -S /usr/bin/curl` ; `rpm -qf /usr/bin/curl`.
3. `remove` garde les fichiers de configuration, `purge` les supprime aussi.
4. Une clé ajoutée globalement est valable pour tous les dépôts ; on utilise un trousseau dédié avec `signed-by=`.
5. `sudo apt-mark hold docker-ce`.
6. *Removed, Config remaining* : paquet supprimé mais configuration conservée.
7. `sudo apt -f install` (ou installer avec `apt install ./fichier.deb`).
8. `-y` avec `DEBIAN_FRONTEND=noninteractive`.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 08` · **Suivant** : [09 — Scripting Bash](../09-scripting-bash/README.md)
