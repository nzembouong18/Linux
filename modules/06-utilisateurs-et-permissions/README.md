# Module 06 — Utilisateurs, groupes et permissions

> **Niveau** : Débutant | **Durée** : 4 h (2 h cours + 2 h labo) | **Prérequis** : modules 02–05
>
> **Objectifs** — À la fin de ce module vous saurez :
> - gérer comptes utilisateurs et groupes (`useradd`, `usermod`, `groupadd`, `passwd`, `chage`) ;
> - lire et modifier les permissions (`chmod`, `chown`, `umask`) en notation symbolique et octale ;
> - utiliser les bits spéciaux `setuid`, `setgid`, *sticky* ;
> - déléguer proprement avec `sudo` ;
> - appliquer des droits fins avec les **ACL** et les attributs de fichier.

---

## 1. Le modèle de sécurité Unix

Chaque **processus** s'exécute avec l'identité d'un **utilisateur** (UID) et de **groupes** (GID). Chaque **fichier** appartient à un utilisateur et à un groupe, et porte des **permissions** pour 3 catégories : propriétaire (**u**ser), groupe (**g**roup), autres (**o**thers).

| UID | Usage |
|----:|-------|
| 0 | **root** — tout-puissant, ignore les permissions |
| 1–999 | comptes **système** (services : `www-data`, `sshd`, `postgres`…) — pas de connexion |
| 1000+ | comptes **humains** |
| 65534 | `nobody` |

> Principe du **moindre privilège** : chaque personne ou service ne reçoit que les droits nécessaires. On ne travaille pas en `root` : on utilise `sudo` au besoin.

## 2. Qui suis-je ? Qui est connecté ?

```bash
whoami              # nom de l'utilisateur effectif
id                  # uid, gid et tous les groupes
id alice            # pour un autre utilisateur
groups              # mes groupes
who ; w             # utilisateurs connectés (w : + activité)
last -n 5           # dernières connexions (/var/log/wtmp)
lastlog             # dernière connexion de chaque compte
```

## 3. Les fichiers de comptes

| Fichier | Contenu | Droits |
|---------|---------|--------|
| `/etc/passwd` | comptes (lisible par tous) | 644 |
| `/etc/shadow` | **hachages de mots de passe**, expiration | 640 `root:shadow` |
| `/etc/group` | groupes et leurs membres | 644 |
| `/etc/gshadow` | mots de passe de groupe | 640 |
| `/etc/skel/` | modèle copié dans les nouveaux `$HOME` | |
| `/etc/login.defs` | défauts (UID_MIN, durée de mot de passe…) | |

```text
/etc/passwd :  alice:x:1001:1001:Alice Martin:/home/alice:/bin/bash
               │     │ │    │    │            │           └─ shell de connexion (/usr/sbin/nologin = pas de login)
               │     │ │    │    │            └─ répertoire personnel
               │     │ │    │    └─ commentaire (GECOS)
               │     │ │    └─ GID du groupe principal
               │     │ └─ UID
               │     └─ x = le hachage est dans /etc/shadow
               └─ nom

/etc/shadow : alice:$y$j9T$salt$hash:19800:0:90:7:::
                    │               │    │ │  └─ avertissement (jours)
                    │               │    │ └─ durée de validité max (jours)
                    │               │    └─ durée min entre changements
                    │               └─ dernier changement (jours depuis 1970)
                    └─ $y$ = yescrypt · $6$ = SHA-512 · ! ou * devant = compte verrouillé
```

Interrogez avec `getent` (respecte LDAP, SSSD…) plutôt que de lire les fichiers :

```bash
getent passwd alice
getent group sudo
```

## 4. Gérer les utilisateurs

```bash
sudo useradd -m -s /bin/bash -c "Alice Martin" alice     # -m crée le HOME
sudo useradd -m -G sudo,docker -s /bin/bash bob           # + groupes supplémentaires
sudo useradd -r -s /usr/sbin/nologin -d /var/lib/monsvc monsvc    # compte système (service)
sudo passwd alice                      # définit le mot de passe (interactif)
echo 'alice:Secret123!' | sudo chpasswd     # non interactif (scripts de labo uniquement !)
sudo usermod -aG developers alice      # AJOUTE au groupe (-a indispensable avec -G !)
sudo usermod -s /bin/zsh alice         # change le shell
sudo usermod -L alice ; sudo usermod -U alice      # verrouille / déverrouille
sudo userdel alice                     # supprime le compte
sudo userdel -r alice                  # + son HOME et sa boîte mail
```

> ⚠️ `usermod -G dev alice` **remplace** tous les groupes supplémentaires. Toujours `-aG`.
> Après changement de groupe, l'utilisateur doit **se reconnecter** (ou `newgrp dev` / `su - alice`).

Debian propose aussi les scripts conviviaux `adduser` / `deluser` (interactifs, avec modèle `/etc/adduser.conf`).

### Politique de mots de passe

```bash
sudo chage -l alice                    # état d'expiration
sudo chage -M 90 -m 1 -W 7 alice       # max 90 j, min 1 j, avertissement 7 j
sudo chage -d 0 alice                  # force le changement à la prochaine connexion
sudo chage -E 2025-12-31 alice         # date d'expiration du compte
sudo passwd -S alice                   # statut : P (utilisable), L (verrouillé), NP (sans mot de passe)
```

## 5. Gérer les groupes

```bash
sudo groupadd developers
sudo groupadd -g 2000 compta               # GID imposé
sudo gpasswd -a alice developers           # ajoute
sudo gpasswd -d alice developers           # retire
sudo groupdel developers
getent group developers
```

Un utilisateur a **un groupe principal** (nouveaux fichiers) et **des groupes secondaires**. Sur Debian/Ubuntu, chaque utilisateur a par défaut un groupe privé du même nom (*User Private Group*).

## 6. Changer d'identité : `su` et `sudo`

```bash
su - alice                 # devient alice avec son environnement (login shell)
su -                       # devient root (nécessite le mot de passe root)
sudo commande              # exécute UNE commande en root
sudo -u postgres psql      # exécute en tant qu'un autre utilisateur
sudo -i                    # shell root interactif (à éviter)
sudo -l                    # que puis-je faire avec sudo ?
```

**Pourquoi sudo plutôt que su ?** Traçabilité (chaque commande est journalisée dans `/var/log/auth.log`), pas de mot de passe root partagé, droits fins, expiration automatique.

### Configurer sudoers

Toujours avec `visudo` (vérifie la syntaxe) ou un fichier dans `/etc/sudoers.d/` :

```bash
sudo visudo -f /etc/sudoers.d/devops
```

```sudoers
# qui    où=(en tant que)  quoi
alice    ALL=(ALL:ALL) ALL                           # tous les droits
%admins  ALL=(ALL) ALL                               # le groupe admins
bob      ALL=(root) /usr/bin/systemctl restart nginx, /usr/bin/journalctl   # commandes précises
deploy   ALL=(ALL) NOPASSWD: /usr/local/bin/deploy.sh                       # sans mot de passe (à limiter !)
Defaults log_output                                  # journalise les sessions
```

Groupes d'administration par défaut : `sudo` (Debian/Ubuntu), `wheel` (Red Hat).

## 7. Les permissions

```text
 -rwxr-x---  1  alice  dev  1204  mars 12 script.sh
  └┬┘└┬┘└┬┘
   │  │  └─ autres (o) : aucun droit
   │  └─ groupe (g)   : lecture + exécution
   └─ propriétaire (u): lecture + écriture + exécution
```

| Droit | Sur un **fichier** | Sur un **répertoire** |
|-------|--------------------|----------------------|
| **r** (4) | lire le contenu | **lister** les noms (`ls`) |
| **w** (2) | modifier le contenu | **créer, renommer, supprimer** des entrées |
| **x** (1) | exécuter (programme/script) | **traverser** (`cd`, accéder aux fichiers par leur nom) |

Subtilités importantes :
- Pour **supprimer** un fichier, ce sont les droits `w`+`x` du **répertoire** qui comptent, pas ceux du fichier.
- Sans `x` sur un dossier, impossible d'accéder à son contenu même avec `r` sur les fichiers.
- `root` ignore les permissions (hors attributs immuables et SELinux).

### `chmod` — notation octale

Chaque triplet = somme `r=4 + w=2 + x=1` :

| Octal | Symbole | Usage courant |
|------:|---------|---------------|
| 600 | `rw-------` | clés privées, fichiers secrets |
| 644 | `rw-r--r--` | fichiers normaux |
| 640 | `rw-r-----` | fichiers partagés avec un groupe |
| 700 | `rwx------` | dossier privé (`~/.ssh`) |
| 750 | `rwxr-x---` | programme pour le groupe |
| 755 | `rwxr-xr-x` | programmes, dossiers publics |
| 777 | `rwxrwxrwx` | ⚠️ à ÉVITER |

```bash
chmod 640 secret.txt
chmod 755 script.sh
chmod -R 750 dossier/
```

### `chmod` — notation symbolique

`[ugoa][+-=][rwxXst]`

```bash
chmod u+x script.sh          # ajoute x au propriétaire
chmod go-rwx prive.txt       # retire tout au groupe et aux autres
chmod a+r public.txt         # lecture pour tous
chmod g=rw,o= fichier        # groupe rw, autres rien
chmod -R u=rwX,go=rX dossier # X = x seulement pour les dossiers (et fichiers déjà exécutables)
```

### `chown` et `chgrp`

```bash
sudo chown alice fichier
sudo chown alice:dev fichier         # propriétaire et groupe
sudo chown :dev fichier              # groupe seulement (= chgrp dev)
sudo chown -R www-data:www-data /var/www/site
sudo chown --reference=modele cible  # copie propriétaire d'un autre fichier
```

Seul root peut changer le propriétaire. Un utilisateur peut changer le groupe d'un fichier vers un de **ses** groupes.

### `umask` — droits par défaut

Les nouveaux fichiers partent de 666 (jamais exécutables), les dossiers de 777, **moins** le masque.

| umask | Fichiers | Dossiers | Usage |
|------:|---------:|---------:|-------|
| 022 | 644 | 755 | défaut Debian/RHEL root |
| 002 | 664 | 775 | travail en équipe (groupe privé) |
| 027 | 640 | 750 | serveur : rien pour les autres |
| 077 | 600 | 700 | confidentiel |

```bash
umask          # affiche   |   umask 027   # change pour la session
```
Persistant : `~/.bashrc`, `/etc/profile`, `/etc/login.defs` (`UMASK`).

## 8. Bits spéciaux

| Bit | Octal | Sur fichier exécutable | Sur répertoire |
|-----|------:|------------------------|----------------|
| **setuid** (`s` côté u) | 4000 | s'exécute avec les droits du **propriétaire** (ex. `passwd`, `sudo`) | — |
| **setgid** (`s` côté g) | 2000 | s'exécute avec le **groupe** du fichier | les nouveaux fichiers **héritent du groupe du dossier** (idéal pour dossiers partagés) |
| **sticky** (`t` côté o) | 1000 | — | seul le **propriétaire du fichier** (ou du dossier, ou root) peut supprimer/renommer (ex. `/tmp`) |

```bash
chmod 2775 /srv/projet        # setgid sur dossier partagé
chmod +t /srv/depot ; chmod 1777 /tmp
ls -l /usr/bin/passwd         # -rwsr-xr-x : setuid root
find / -xdev -perm -4000 -type f 2>/dev/null     # audit des binaires setuid
```

`s` / `t` en majuscule (`S`, `T`) signifie que le bit `x` correspondant est absent (souvent une erreur).

> 🔐 Les binaires setuid root sont une cible privilégiée d'attaque : n'en créez que si indispensable, jamais sur un script.

## 9. ACL — permissions fines

Les permissions ugo sont limitées (un seul propriétaire, un seul groupe). Les **ACL POSIX** permettent d'accorder des droits à des utilisateurs/groupes supplémentaires.

```bash
sudo apt install acl
setfacl -m u:carol:rx projet/            # carol : lecture + traversée
setfacl -m g:audit:r projet/rapport.txt  # groupe audit : lecture
setfacl -d -m g:equipe:rwx projet/       # ACL PAR DÉFAUT héritée par les nouveaux fichiers
setfacl -x u:carol projet/               # retire l'entrée de carol
setfacl -b projet/                       # supprime toutes les ACL
getfacl projet/                          # affiche
ls -l projet                             # un « + » en fin de droits signale des ACL
```

## 10. Attributs de fichier (ext4/xfs)

```bash
sudo chattr +i /etc/resolv.conf     # immuable : même root ne peut ni modifier ni supprimer
sudo chattr +a /var/log/audit.log   # append-only
lsattr /etc/resolv.conf
sudo chattr -i /etc/resolv.conf     # lever
```

## 11. Bonnes pratiques

1. Un compte nominatif par personne ; jamais de compte partagé.
2. Comptes de service : `useradd -r -s /usr/sbin/nologin`, sans mot de passe.
3. Pas de `chmod 777`. Cherchez le vrai problème (propriétaire ? groupe ?).
4. Groupes pour les accès partagés + dossier `setgid` + `umask 002/007`.
5. Clés SSH plutôt que mots de passe (module 12) ; mot de passe root verrouillé (`passwd -l root`).
6. `sudo` avec commandes précises, journalisation activée.
7. Auditez régulièrement : comptes sans mot de passe (`awk -F: '$2==""' /etc/shadow`), UID 0 multiples (`awk -F: '$3==0' /etc/passwd`), fichiers world-writable.

## 12. Résumé

- Identité : UID/GID, `id`, `/etc/passwd|shadow|group`.
- Comptes : `useradd -m`, `usermod -aG`, `passwd`, `chage`, `userdel -r`.
- Droits : `rwx` × `ugo`, octal 4-2-1, `chmod`, `chown`, `umask` ; `x` sur un dossier = traverser.
- Spéciaux : setuid (4000), setgid (2000), sticky (1000).
- `sudo` + `visudo`, ACL (`setfacl`), `chattr +i`.

## 13. Quiz

1. Que signifie `drwxr-sr-x` ?
2. Quels droits donne `chmod 640` ? Et `umask 027` aux nouveaux fichiers ?
3. Pourquoi `usermod -G` peut-il retirer un utilisateur de ses groupes ?
4. Un fichier est `rw-r--r--` et appartient à alice. Bob peut-il le supprimer si le dossier est `drwxrwxrwx` ? Et si le dossier a le sticky bit ?
5. Quelle est la différence entre `su -` et `sudo -i` ?
6. Comment rendre un fichier impossible à supprimer même par root ?
7. Quel est l'intérêt du bit setgid sur un répertoire partagé ?
8. Comment donner à carol seule un accès en lecture à un fichier sans changer propriétaire/groupe ?

<details><summary>Réponses</summary>

1. Répertoire, propriétaire `rwx`, groupe `r-x` avec **setgid**, autres `r-x`.
2. 640 = `rw-r-----`. Avec `umask 027`, les fichiers sont créés en 640.
3. Sans `-a`, la liste des groupes secondaires est remplacée.
4. Oui s'il n'y a pas de sticky (droit `w` sur le dossier). Avec sticky : non, seul alice ou le propriétaire du dossier/root.
5. `su -` demande le mot de passe de root ; `sudo -i` demande le vôtre et journalise.
6. `chattr +i fichier`.
7. Les nouveaux fichiers héritent du groupe du dossier, donc toute l'équipe peut y collaborer.
8. `setfacl -m u:carol:r fichier`.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 06` · **Suivant** : [07 — Processus et signaux](../07-processus-et-signaux/README.md)
