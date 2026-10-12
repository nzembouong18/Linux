# Module 15 — Journaux, archivage, compression et sauvegardes

> **Niveau** : Intermédiaire | **Durée** : 5 h (2 h 30 cours + 2 h 30 labo) | **Prérequis** : modules 03, 05, 09, 14
>
> **Objectifs** — À la fin de ce module vous saurez :
> - localiser, lire et filtrer les journaux système (`/var/log`, `journalctl`, `rsyslog`) ;
> - configurer la **rotation** des journaux (`logrotate`) ;
> - archiver et compresser (`tar`, `gzip`, `bzip2`, `xz`, `zstd`) ;
> - concevoir une **stratégie de sauvegarde** (règle 3-2-1, RPO/RTO) et l'automatiser (`rsync`, snapshots par liens durs) ;
> - **tester les restaurations** — la seule sauvegarde qui compte est celle que l'on sait restaurer.

---

## 1. Où sont les journaux ?

Deux mondes cohabitent :

| Système | Où | Outil de lecture |
|---------|-----|------------------|
| **journald** (systemd) | binaire, `/run/log/journal` (volatil) ou `/var/log/journal` (persistant) | `journalctl` |
| **rsyslog / syslog** | fichiers texte dans `/var/log/` | `less`, `grep`, `tail -F` |

| Fichier (Debian/Ubuntu → RHEL) | Contenu |
|--------------------------------|---------|
| `syslog` → `messages` | messages généraux |
| `auth.log` → `secure` | authentifications : SSH, sudo, su |
| `kern.log`, `dmesg` | noyau, matériel, OOM-killer |
| `dpkg.log`, `apt/history.log` → `dnf.log` | installations de paquets |
| `nginx/access.log`, `error.log` | serveur web |
| `mysql/`, `postgresql/` | bases de données |
| `cron.log` (ou syslog) | tâches cron |
| `wtmp`, `btmp`, `lastlog` | connexions réussies / échouées (binaires : `last`, `lastb`, `lastlog`) |
| `audit/audit.log` | auditd (SELinux, règles d'audit) |

### Lire efficacement

```bash
sudo tail -F /var/log/syslog                         # suivre
sudo grep -i 'error\|fail' /var/log/syslog | tail -20
sudo grep 'Failed password' /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head   # IP attaquantes
journalctl -u ssh --since today -p warning
journalctl -b -1 -p err                              # erreurs du démarrage précédent (après un plantage)
journalctl -k | grep -i -E 'oom|killed process|I/O error'
last -n 10 ; sudo lastb -n 10                        # connexions / échecs
dmesg -T --level=err,warn
```

### `journalctl` en profondeur
journald stocke les journaux dans un format **binaire indexé** : les requêtes par service, priorité ou date sont très rapides, et chaque entrée porte des **champs structurés** (`_SYSTEMD_UNIT`, `_PID`, `PRIORITY`, `_HOSTNAME`…).
```bash
journalctl -u nginx -u php-fpm --since "2 hours ago" --until "10 minutes ago"   # plusieurs unités, fenêtre de temps
journalctl -p err..alert                         # plage de priorités (0 emerg … 7 debug)
journalctl -f -u ssh                             # suivre en direct
journalctl -n 100 --no-pager                     # 100 dernières lignes, sans pagination
journalctl -o json-pretty -n 1                   # voir TOUS les champs d'une entrée
journalctl -o short-iso                          # horodatage ISO 8601 (corrélation facile)
journalctl _PID=1234                             # filtrer par champ
journalctl _SYSTEMD_UNIT=cron.service _UID=0
journalctl /usr/sbin/sshd                        # tous les messages d'un exécutable
journalctl --list-boots                          # démarrages enregistrés (nécessite la persistance)
journalctl --disk-usage ; journalctl --verify    # taille / intégrité
journalctl -g 'timeout|refused'                  # recherche par expression régulière (--grep)
journalctl -k -b                                 # messages du noyau depuis ce démarrage
journalctl --since "2024-03-12 14:00" -o cat     # seulement le texte des messages
```
**Rendre les journaux persistants** (sinon ils disparaissent au redémarrage, ce qui empêche l'analyse post-mortem) :
```bash
sudo mkdir -p /var/log/journal && sudo systemd-tmpfiles --create --prefix /var/log/journal
# ou dans /etc/systemd/journald.conf : Storage=persistent
sudo systemctl restart systemd-journald
```
**Limiter la taille** (`/etc/systemd/journald.conf`) : `SystemMaxUse=1G`, `SystemKeepFree=2G`, `MaxRetentionSec=1month`, `RateLimitIntervalSec`/`RateLimitBurst` (un service très bavard peut voir ses messages supprimés : « Suppressed N messages »). **Droits** : pour lire tous les journaux sans `sudo`, ajoutez l'utilisateur aux groupes `systemd-journal` ou `adm`.

**Écrire dans le journal depuis un script** : `logger -t mon-script -p user.info "sauvegarde terminée"` (visible par `journalctl -t mon-script`). Un service systemd capture déjà stdout/stderr : un simple `echo` suffit.

**Du journal vers un système central.** `rsyslog` peut relayer vers un serveur (`*.* @@loghost:514`), ou on utilise un agent (Promtail/Alloy, Fluent Bit, Filebeat) qui lit le journal. Centraliser les journaux protège contre l'effacement par un attaquant et permet de corréler plusieurs machines (synchronisez les horloges : `timedatectl`, chrony).

### Que journaliser et comment lire un incident
1. Fixez l'**heure de début** du problème (utilisateur, supervision) et ouvrez une fenêtre un peu plus large (`--since`/`--until`).
2. Commencez par la **priorité** (`-p err`) puis élargissez.
3. Cherchez le **premier** message anormal, pas le dernier : les erreurs en cascade masquent la cause.
4. Corrélez les sources : application (`-u service`), noyau (`-k`), authentification (`auth.log`), réseau.
5. Notez les horodatages et les extraits dans le rapport d'incident.

### rsyslog : facilités et priorités

Un message syslog a une **facility** (`auth`, `authpriv`, `cron`, `daemon`, `kern`, `mail`, `user`, `local0`…`local7`) et une **severity** (0 `emerg`, 1 `alert`, 2 `crit`, 3 `err`, 4 `warning`, 5 `notice`, 6 `info`, 7 `debug`).

```text
# /etc/rsyslog.d/50-app.conf
local3.*                     /var/log/monapp.log
*.err                        /var/log/erreurs.log
auth,authpriv.*              /var/log/auth.log
*.* @@logserver.example.org:514      # envoi TCP vers un serveur central (@ = UDP)
```
```bash
logger -p local3.info -t monapp "démarrage terminé"    # écrire dans syslog depuis un script
sudo systemctl restart rsyslog
```

Bonnes pratiques : **centraliser** les journaux hors de la machine (syslog central, Loki, ELK/OpenSearch, Graylog) ; synchroniser l'heure (NTP/chrony) ; ne pas laisser un attaquant effacer ses traces (envoi distant, `chattr +a`) ; surveiller l'espace disque de `/var/log`.

## 2. `logrotate` — empêcher les journaux de saturer le disque

`logrotate` (lancé quotidiennement par `cron` ou un timer) renomme, compresse, supprime les anciens journaux.

`/etc/logrotate.d/monapp` :

```text
/var/log/monapp/*.log {
    daily                     # weekly, monthly, ou "size 100M" / "maxsize 100M"
    rotate 14                 # conserve 14 générations
    compress                  # gzip
    delaycompress             # ne compresse que la 2e génération (le 1er .1 reste lisible/ouvert)
    missingok                 # pas d'erreur si le fichier manque
    notifempty                # ne tourne pas si vide
    create 0640 monapp adm    # recrée le fichier avec ces droits
    sharedscripts
    postrotate
        systemctl kill -s HUP monapp.service 2>/dev/null || true     # demande au service de rouvrir son journal
    endscript
}
```

Alternative sans signal : `copytruncate` (copie puis vide — peut perdre quelques lignes).

```bash
sudo logrotate -d /etc/logrotate.d/monapp      # -d debug : simule, ne change rien
sudo logrotate -f /etc/logrotate.conf          # -f force la rotation maintenant
cat /var/lib/logrotate/status                  # dates de dernière rotation
sudo journalctl --vacuum-time=30d              # journald a ses propres limites : /etc/systemd/journald.conf (SystemMaxUse=)
```

## 3. Archiver avec `tar`

`tar` (*tape archive*) assemble plusieurs fichiers/dossiers en **une archive** en conservant droits, propriétaires, dates, liens ; la compression est une option.

```bash
tar -cvf archive.tar dossier/                 # c create · v verbose · f fichier
tar -czvf archive.tar.gz dossier/             # + z gzip
tar -cJf archive.tar.xz dossier/              # J xz  (meilleur taux, plus lent)
tar --zstd -cf archive.tar.zst dossier/       # zstd (très bon compromis vitesse/taux)
tar -tzf archive.tar.gz                       # t : LISTER sans extraire
tar -xzf archive.tar.gz                       # x : extraire ici
tar -xzf archive.tar.gz -C /restauration      # -C : dans un autre dossier
tar -xzf archive.tar.gz dossier/fichier.txt   # extraire un seul fichier
tar -czf backup.tgz --exclude='*.tmp' --exclude='cache' -C /srv donnees     # exclusions + chemins relatifs
tar -czf - dossier | ssh srv 'cat > /backup/dossier.tgz'                    # via un flux
tar -cpf - /data | tar -xpf - -C /copie       # copie fidèle (p : conserve les permissions)
tar -czf incr.tgz --listed-incremental=suivi.snar /data     # sauvegarde incrémentale GNU
```

Bonnes pratiques :
- **Chemins relatifs** (`-C /srv donnees`) : évitez d'archiver `/srv/donnees` en absolu (extraction dangereuse).
- Toujours **lister** (`tar -tf`) avant d'extraire une archive inconnue (chemins `../`).
- En root, `tar -x` restaure propriétaires et droits ; `--numeric-owner` si les UID/GID diffèrent entre machines.
- Fichiers avec attributs étendus/ACL/SELinux : `--xattrs --acls --selinux`.

### Compresseurs

| Outil | Extension | Vitesse | Taux | Commentaire |
|-------|-----------|---------|------|-------------|
| `gzip` | `.gz` | rapide | moyen | universel (`-1`…`-9`, `zcat`, `zgrep`) |
| `bzip2` | `.bz2` | lent | bon | en déclin |
| `xz` | `.xz` | **très lent** | **excellent** | distribution de paquets, archives froides ; `-T0` multi-cœurs |
| `zstd` | `.zst` | **très rapide** | très bon | choix moderne (`-3` défaut, `-19`, `-T0`) |
| `zip`/`unzip` | `.zip` | | | échange avec Windows |

```bash
gzip -k -9 gros.log                  # -k : garde l'original
gunzip gros.log.gz ; xz -dk f.xz ; zstd -d f.zst
zcat access.log.2.gz | grep 404 ; zgrep -c ERROR /var/log/*.gz ; xzcat, bzcat, zstdcat
ls -l gros.log*; xz -T0 -9 -k gros.log
```

Autres : `cpio`, `ar`, `7z`, `dd` (copie de bas niveau de disques : `dd if=/dev/sda of=disque.img bs=4M status=progress`, ⚠ `if`/`of` inversés = catastrophe).

## 4. Intégrité : sommes de contrôle

```bash
sha256sum fichier.iso                        # empreinte
sha256sum -c SHA256SUMS                      # vérifie une liste (OK / FAILED)
find /backup -type f -print0 | sort -z | xargs -0 sha256sum > manifest.sha256
gpg --verify fichier.iso.sig fichier.iso     # authenticité (signature)
```

## 5. Stratégie de sauvegarde

> « Il y a deux types d'administrateurs : ceux qui font des sauvegardes et ceux qui vont en faire. »

**Définitions**

- **RPO** (*Recovery Point Objective*) : perte de données maximale acceptable (« on peut perdre 1 h de données »). Détermine la **fréquence**.
- **RTO** (*Recovery Time Objective*) : durée maximale d'indisponibilité acceptable. Détermine la **technique** de restauration.
- **Rétention** : combien de temps garder chaque sauvegarde (ex. 7 quotidiennes, 4 hebdomadaires, 12 mensuelles).

**Règle 3-2-1** : **3** copies des données, sur **2** supports différents, dont **1** hors site (et idéalement **1** immuable/hors ligne contre les rançongiciels : « 3-2-1-1-0 » = + 1 copie hors-ligne + 0 erreur après test de restauration).

| Type | Principe | Remarque |
|------|----------|----------|
| Complète | tout, à chaque fois | simple, gourmande |
| Différentielle | changements depuis la dernière complète | restauration = 2 jeux |
| **Incrémentale** | changements depuis la dernière sauvegarde | économe, restauration = chaîne |
| **Snapshots** (LVM, Btrfs/ZFS, VM) | copie instantanée cohérente | ne remplace pas une copie externe |
| **Dédoublonnée** (borg, restic) | blocs uniques, chiffrées | recommandé pour du moderne |

**Sauvegardes cohérentes** : une base de données se sauvegarde par dump (`pg_dump`, `mysqldump --single-transaction`) ou snapshot cohérent, **pas** en copiant les fichiers en cours d'écriture.

**Que sauvegarder ?** Données (`/home`, `/srv`, `/var/lib/…`), configuration (`/etc`), listes de paquets (`dpkg --get-selections`), scripts, secrets (chiffrés), bases. Pas : `/proc`, `/sys`, `/dev`, `/run`, `/tmp`, caches, ce qui se réinstalle.

### Outils

| Outil | Pour quoi |
|-------|----------|
| **rsync** | synchronisation, snapshots par liens durs, simple et fiable |
| **borgbackup** | sauvegardes dédoublonnées, compressées, chiffrées, via SSH |
| **restic** | idem, nombreux backends (S3, SFTP, Azure…) |
| **duplicity / duplicati** | chiffrement GPG, stockage cloud |
| **rclone** | « rsync pour le cloud » |
| **Bacula / Bareos / Amanda / Veeam** | solutions d'entreprise |
| **timeshift / snapper** | snapshots système (Btrfs/LVM) |

### Snapshots incrémentaux par liens durs avec `rsync`

Chaque exécution crée un dossier horodaté qui *ressemble* à une sauvegarde complète, mais les fichiers inchangés sont des **liens durs** vers la version précédente : espace minimal, restauration triviale (un simple `cp`).

```bash
#!/usr/bin/env bash
set -euo pipefail
SRC=/srv/donnees/ ; DEST=/backup/donnees ; NAME=$(date +%F_%H%M%S)
mkdir -p "$DEST"
LINK=()
[[ -e "$DEST/latest" ]] && LINK=(--link-dest="$(readlink -f "$DEST/latest")")
rsync -a --delete "${LINK[@]}" "$SRC" "$DEST/$NAME/"
ln -sfn "$NAME" "$DEST/latest"
# rétention : garder les 14 derniers
ls -1d "$DEST"/20* | head -n -14 | xargs -r rm -rf
```

```bash
ls -li /backup/donnees/*/fichier.txt    # même inode = lien dur = pas de duplication
du -sh /backup/donnees/*                # du compte chaque inode une seule fois dans l'ensemble
```

### Planifier et surveiller

- Planification : timer systemd ou cron (module 14), avec `flock` contre les chevauchements.
- **Alerter en cas d'échec** : `OnFailure=` systemd, mail, outil de supervision (« la sauvegarde n'a pas tourné » est la panne la plus silencieuse). Services de type *dead man's switch* (healthchecks.io).
- **Tester la restauration** régulièrement (idéalement automatisée) : extraire dans un dossier temporaire, comparer les empreintes, démarrer l'application de test.
- Chiffrer les sauvegardes hors site : `age`, `gpg -c`, chiffrement natif de borg/restic. Protéger la clé **séparément**.

## 6. Procédure de restauration (exemple)

```bash
tar -tzf /backup/site-2024-03-10.tgz | head                      # 1. inspecter
mkdir /tmp/restore && tar -xzf /backup/site-2024-03-10.tgz -C /tmp/restore     # 2. extraire à côté (jamais directement par-dessus)
diff -r /tmp/restore/srv/site /srv/site | head                   # 3. comparer
sudo rsync -a /tmp/restore/srv/site/ /srv/site/                  # 4. restaurer
```

## 7. Résumé

- Journaux : `journalctl` (systemd) + `/var/log` (rsyslog) ; centralisez-les ; **`logrotate`** évite la saturation.
- `tar -czf` / `-xzf` / `-tzf` (+ `-C`, `--exclude`) ; compresseurs : gzip (rapide), xz (taux), zstd (équilibre).
- **3-2-1**, RPO, RTO, rétention ; `rsync --link-dest` pour des snapshots économes.
- Vérifiez avec `sha256sum`, surveillez les échecs, **testez les restaurations**.

## 8. Quiz

1. Où chercher les tentatives de connexion SSH échouées sur Ubuntu ? Et sur RHEL ?
2. À quoi servent `delaycompress` et `postrotate` dans logrotate ?
3. Quelle commande liste le contenu d'une archive `.tar.gz` sans l'extraire ? Pourquoi le faire ?
4. Que signifient RPO et RTO ? Que décide chacun ?
5. Expliquez la règle 3-2-1.
6. Comment fonctionne `rsync --link-dest` et pourquoi est-ce économe ?
7. Pourquoi ne pas copier directement les fichiers d'une base en fonctionnement ?
8. Quelle est la différence entre une sauvegarde incrémentale et différentielle ?

<details><summary>Réponses</summary>

1. `/var/log/auth.log` (ou `journalctl -u ssh`) ; `/var/log/secure` (ou `journalctl -u sshd`).
2. `delaycompress` : laisse la dernière rotation non compressée (le service peut encore y écrire) ; `postrotate` exécute une commande après rotation (rouvrir le journal).
3. `tar -tzf archive.tar.gz` ; pour vérifier le contenu et détecter des chemins dangereux (`../`, absolus).
4. RPO : perte de données maximale tolérée → fréquence des sauvegardes. RTO : temps d'arrêt maximal toléré → moyens de restauration.
5. 3 copies, 2 supports différents, 1 hors site.
6. Les fichiers inchangés sont des liens durs vers la sauvegarde précédente : un seul exemplaire sur disque, chaque dossier paraît complet.
7. Incohérence (fichiers copiés à des instants différents, transactions en cours) ; utiliser dump logique ou snapshot cohérent.
8. Incrémentale : depuis la **dernière sauvegarde** ; différentielle : depuis la **dernière complète**.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 15` · **Suivant** : [16 — Sécurité et durcissement](../16-securite-et-durcissement/README.md)
