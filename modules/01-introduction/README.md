# Module 01 — Introduction à Linux et mise en place du labo

> **Niveau** : Débutant | **Durée** : 2 h (1 h cours + 1 h labo) | **Prérequis** : aucun
>
> **Objectifs** — À la fin de ce module vous saurez :
> - distinguer *noyau*, *système d'exploitation* et *distribution* ;
> - choisir une distribution adaptée à un besoin ;
> - installer votre environnement d'entraînement (conteneur, VM ou WSL2) ;
> - interroger le système pour connaître sa version, son matériel et son état ;
> - trouver de l'aide par vous-même (`man`, `--help`, `apropos`).

---

## 1. Qu'est-ce que Linux ?

**Linux est un noyau (*kernel*)**, pas un système complet. Le noyau est le programme qui :

- gère le **matériel** (CPU, mémoire, disques, réseau) ;
- **partage** les ressources entre les programmes (ordonnancement, mémoire virtuelle) ;
- expose aux programmes une interface standard : les **appels système** (*syscalls* : `open`, `read`, `fork`, `execve`…) ;
- applique la **sécurité** (utilisateurs, permissions, isolation).

Un « système Linux » complet = **noyau Linux + outils GNU + bibliothèque C + shell + gestionnaire de paquets + …** C'est pourquoi on parle parfois de *GNU/Linux*. Cet assemblage s'appelle une **distribution**.

```text
┌───────────────────────────────────────────────┐
│  Applications (navigateur, nginx, python, …)  │   ← espace utilisateur
├───────────────────────────────────────────────┤
│  Shell (bash) · outils (ls, grep, systemd)    │
├───────────────────────────────────────────────┤
│  Bibliothèques (glibc / musl)                 │
╞═══════════════════════════════════════════════╡  ← frontière : appels système
│  NOYAU LINUX                                  │   ← espace noyau
│  (processus · mémoire · fichiers · réseau)    │
├───────────────────────────────────────────────┤
│  Matériel (CPU, RAM, disques, cartes réseau)  │
└───────────────────────────────────────────────┘
```

### Un peu d'histoire

| Année | Événement |
|------:|-----------|
| 1969 | Naissance d'**Unix** aux Bell Labs (Ken Thompson, Dennis Ritchie) |
| 1983 | Richard Stallman lance le projet **GNU** (outils libres) |
| 1991 | Linus Torvalds publie la première version du **noyau Linux** |
| 1993 | Debian et Slackware : premières distributions durables |
| 2004 | Ubuntu rend Linux accessible au grand public |
| 2010+ | Linux domine le cloud, l'embarqué, Android, les supercalculateurs |

> **Aujourd'hui** : 100 % du top 500 des supercalculateurs, la grande majorité des serveurs web et des instances cloud, Android (noyau Linux), les routeurs, les téléviseurs… tournent sous Linux.

## 2. La philosophie Unix

1. **Un programme = une tâche, bien faite** (`ls` liste, `grep` filtre, `sort` trie).
2. **Les programmes coopèrent** via des flux de texte (les *pipes*, module 05).
3. **Tout est fichier** : disque, terminal, périphérique, processus (`/proc`), socket…
4. **Le texte est l'interface universelle** : configuration en fichiers texte lisibles, versionnables.
5. **Automatiser** plutôt que répéter : on écrit des scripts.

Cette philosophie explique la puissance de la ligne de commande : des briques simples, combinables à l'infini.

## 3. Les distributions

Une distribution choisit : le noyau et ses options, le **gestionnaire de paquets**, le cycle de publication, les outils par défaut, la politique de support.

| Famille | Exemples | Paquets | Usage typique |
|---------|----------|---------|---------------|
| **Debian** | Debian, Ubuntu, Linux Mint, Kali | `.deb` · `apt` / `dpkg` | Serveurs, poste de travail, cloud |
| **Red Hat** | RHEL, Rocky, AlmaLinux, Fedora, CentOS Stream | `.rpm` · `dnf` / `rpm` | Entreprise, certifications RHCSA |
| **SUSE** | openSUSE, SLES | `.rpm` · `zypper` | Entreprise (SAP), Europe |
| **Arch** | Arch, Manjaro | `pacman` | Passionnés, rolling release |
| **Alpine** | Alpine | `apk` | Conteneurs (image de ~5 Mo) |

**Comment choisir ?**

- *Apprendre / poste de travail* → **Ubuntu LTS** ou Debian.
- *Préparer un environnement d'entreprise* → **Rocky/Alma Linux** (compatible RHEL) ; connaître aussi Debian/Ubuntu.
- *Conteneurs minimalistes* → **Alpine** (attention : `musl` et `busybox`, quelques différences).

> 🎯 **Cette formation utilise Ubuntu 24.04 LTS** comme référence, avec les équivalents Red Hat (`dnf`, SELinux, `firewalld`) indiqués à chaque fois que c'est pertinent. Les concepts sont identiques partout.

**LTS** (*Long Term Support*) = version supportée 5 ans (ou plus) : choisissez-la pour la production.

## 4. Logiciel libre et licences

- **Libre** ≠ gratuit : *libre* = droit d'utiliser, étudier, modifier et redistribuer le code.
- **GPL** (noyau Linux) : toute œuvre dérivée redistribuée doit rester sous GPL (*copyleft*).
- **MIT / BSD / Apache 2.0** : licences permissives (réutilisation quasi libre).
- Support commercial possible : Red Hat, Canonical, SUSE vendent du support, pas le logiciel.

## 5. Installer son environnement d'entraînement

Choisissez **une** des options (par ordre de recommandation) :

### Option A — Conteneur Docker du dépôt (le plus rapide)

```bash
git clone https://github.com/nzembouong18/Linux.git && cd Linux
docker compose up -d --build          # construit l'image « lab » (Ubuntu 24.04 + systemd)
docker compose exec -u student lab bash
student@lab:~$ cd /opt/linux-training && ./lab list
```

Avantages : 2 minutes, jetable (`docker compose down -v` remet tout à zéro). Limites : pas de vrai démarrage (GRUB), quelques labos noyau/disques nécessitent `--privileged` (déjà activé dans `docker-compose.yml`).

### Option B — Machine virtuelle (Vagrant + VirtualBox/libvirt)

```bash
vagrant up            # VM « lab » + VM « srv1 » (réseau/SSH) + disques additionnels
vagrant ssh lab
```

C'est l'option **idéale** pour les modules stockage (13), noyau/boot (21) et réseau avancé (17).

### Option C — WSL2 (Windows)

```powershell
wsl --install -d Ubuntu-24.04
```

### Option D — Installation sur machine physique / VM manuelle

Téléchargez l'ISO Ubuntu Server 24.04 LTS, créez une VM (2 vCPU, 4 Go RAM, 30 Go disque) avec VirtualBox, VMware ou KVM. Pour les labos de stockage, ajoutez 2 disques virtuels de 1 Go.

> ⚠️ **Règle d'or** : ne vous entraînez jamais sur une machine de production ni sur votre poste personnel avec des droits `root` : une faute de frappe dans `rm -rf` ne pardonne pas. Utilisez toujours un environnement jetable.

## 6. Premiers contacts : « Qui suis-je, où suis-je, sur quoi ? »

Ouvrez un terminal et lancez :

```bash
whoami                     # utilisateur courant
hostname                   # nom de la machine
uname -a                   # noyau, architecture
uname -r                   # version du noyau seulement
cat /etc/os-release        # distribution et version
lsb_release -a             # idem (si installé)
uptime                     # durée de fonctionnement + charge moyenne
date                       # date et heure système
echo "$SHELL"              # shell de l'utilisateur
echo "$HOME"               # répertoire personnel
lscpu                      # processeur
nproc                      # nombre de cœurs disponibles
free -h                    # mémoire (h = lisible)
df -h                      # espace disque par système de fichiers
```

**Lire une sortie typique :**

```text
$ uname -a
Linux lab 6.8.0-45-generic #45-Ubuntu SMP x86_64 GNU/Linux
      │   │                │            └─ architecture
      │   │                └─ date/numéro de compilation
      │   └─ version du noyau (majeure.mineure.patch)
      └─ nom de machine
```

La charge moyenne affichée par `uptime` (`load average: 0.15, 0.10, 0.05`) donne le nombre moyen de processus en attente sur 1, 5 et 15 minutes. Sur une machine à 4 cœurs, une charge de 4,0 = saturation.

## 7. Savoir se débrouiller : l'aide intégrée

Un administrateur expérimenté ne connaît pas toutes les options : il sait **où les trouver**.

| Commande | Rôle | Exemple |
|----------|------|---------|
| `man commande` | Manuel complet (navigation : `/` recherche, `n` suivant, `q` quitter) | `man ls` |
| `commande --help` | Résumé rapide des options | `ls --help` |
| `man -k mot` / `apropos mot` | Cherche une commande **par mot-clé** | `apropos "copy files"` |
| `whatis commande` | Description en une ligne | `whatis grep` |
| `type commande` / `which commande` | D'où vient la commande (alias ? binaire ? interne ?) | `type cd` |
| `info commande` | Documentation GNU détaillée | `info coreutils` |
| `/usr/share/doc/<paquet>/` | Exemples et README du paquet | |

Les sections du manuel : **1** commandes utilisateur · **5** formats de fichiers de configuration · **8** commandes d'administration. Exemple : `man 5 passwd` (le fichier) ≠ `man 1 passwd` (la commande).

Comment lire la synopsis : `[option]` facultatif · `<arg>` obligatoire · `a|b` choix · `...` répétable.

## 8. Bonnes pratiques dès le premier jour

- **Lisez avant de taper** une commande copiée-collée depuis Internet.
- Utilisez la **complétion** avec la touche `Tab` (une fois = complète, deux fois = liste) et l'**historique** avec `↑` / `Ctrl+R`.
- Le terminal est **sensible à la casse** : `Fichier` ≠ `fichier`.
- **Pas de nouvelles = bonnes nouvelles** : en général une commande Unix qui réussit n'affiche rien.
- Code retour de la dernière commande : `echo $?` (0 = succès, autre = erreur).

## 9. Résumé

- Linux = **noyau** ; une **distribution** = noyau + userland + paquets + politique.
- Familles principales : Debian/Ubuntu (`apt`), Red Hat (`dnf`), SUSE, Arch, Alpine.
- Philosophie : outils simples, texte, tout est fichier, automatisation.
- `uname`, `/etc/os-release`, `uptime`, `free`, `df`, `lscpu` = tableau de bord de base.
- `man`, `--help`, `apropos` = votre autonomie.

## 10. Quiz

1. Quelle est la différence entre Linux et GNU/Linux ?
2. Citez deux distributions de la famille Debian et deux de la famille Red Hat.
3. Que signifie LTS et pourquoi la préférer en production ?
4. Quelle commande donne la version du noyau ? Et celle de la distribution ?
5. Vous cherchez la commande qui compare deux fichiers mais vous ne la connaissez pas : que tapez-vous ?
6. Quelle section du manuel documente le format du fichier `/etc/passwd` ?
7. Que signifie un code retour de `0` ?

<details><summary>Réponses</summary>

1. *Linux* est le noyau ; *GNU/Linux* désigne le système complet (noyau + outils GNU).
2. Debian : Debian, Ubuntu, Mint, Kali. Red Hat : RHEL, Rocky, AlmaLinux, Fedora, CentOS Stream.
3. *Long Term Support* : mises à jour de sécurité pendant des années sans changement majeur → stabilité.
4. `uname -r` ; `cat /etc/os-release` (ou `lsb_release -a`).
5. `apropos compare files` ou `man -k diff` → `diff`, `cmp`, `comm`.
6. La section 5 : `man 5 passwd`.
7. La commande a réussi.
</details>

## 11. Pour aller plus loin

- *The Linux Command Line* — William Shotts (gratuit, linuxcommand.org).
- <https://www.kernel.org> — sources et documentation du noyau.
- <https://distrowatch.com> — comparer les distributions.

➡️ **Labo** : [LAB.md](LAB.md) · **Démo formateur** : `./lab demo 01` · **Module suivant** : [02 — Terminal et navigation](../02-terminal-et-navigation/README.md)
