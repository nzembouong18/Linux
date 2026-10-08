# Module 14 — systemd, services, journaux, cron et timers

> **Niveau** : Intermédiaire | **Durée** : 6 h (3 h cours + 3 h labo) | **Prérequis** : modules 07, 09
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer le rôle de **systemd** (PID 1, unités, cibles, cgroups) ;
> - démarrer/arrêter/activer des services et diagnostiquer un service en échec ;
> - **écrire une unité de service** robuste et durcie, la surcharger avec un *drop-in* ;
> - lire les journaux avec `journalctl` ;
> - planifier des tâches avec **cron** et des **timers systemd** ;
> - analyser le démarrage et appliquer des limites de ressources.

---

## 1. Qu'est-ce que systemd ?

**systemd** est le gestionnaire de système et de services de la quasi-totalité des distributions modernes (Debian, Ubuntu, RHEL, Fedora, SUSE, Arch). C'est le **processus PID 1** : le premier lancé par le noyau, ancêtre de tous les autres.

Ses rôles : démarrer le système en parallèle, superviser les services (redémarrage automatique), gérer les journaux (`journald`), les montages, les timers, les sockets, les sessions (`logind`), le réseau (`networkd`), la résolution DNS (`resolved`), les ressources (cgroups)…

```text
 Noyau ──► systemd (PID 1) ──► cible (target) par défaut : multi-user.target / graphical.target
                  │
                  ├─ lit les unités (/usr/lib/systemd/system, /etc/systemd/system)
                  ├─ résout les dépendances et ordonne le démarrage (en parallèle)
                  └─ place chaque service dans un cgroup (suivi, limites, arrêt propre)
```

### Types d'unités

| Extension | Rôle |
|-----------|------|
| `.service` | un démon / programme |
| `.socket` | socket qui active un service à la demande |
| `.timer` | déclenchement planifié (≈ cron) |
| `.mount` / `.automount` | point de montage |
| `.target` | groupe d'unités / état du système (≈ niveau d'exécution) |
| `.path` | déclenche sur modification d'un chemin |
| `.slice` | groupe de ressources (cgroup) |

| Cible | Équivalent SysV |
|-------|-----------------|
| `poweroff.target` | niveau 0 |
| `rescue.target` | niveau 1 / mono-utilisateur |
| `multi-user.target` | niveau 3 (serveur, sans graphique) |
| `graphical.target` | niveau 5 |
| `reboot.target` | niveau 6 |

## 2. `systemctl` : piloter les services

```bash
systemctl status nginx                  # état, PID, derniers logs
sudo systemctl start nginx              # démarre maintenant
sudo systemctl stop nginx
sudo systemctl restart nginx            # arrêt + démarrage (coupure)
sudo systemctl reload nginx             # recharge la config sans coupure (si supporté)
sudo systemctl enable nginx             # démarrage AU BOOT (crée un lien symbolique)
sudo systemctl enable --now nginx       # enable + start
sudo systemctl disable --now nginx
sudo systemctl mask nginx               # interdit tout démarrage (lien vers /dev/null)
sudo systemctl unmask nginx

systemctl is-active nginx               # active / inactive / failed (code retour utilisable en script)
systemctl is-enabled nginx
systemctl list-units --type=service --state=running
systemctl list-unit-files --type=service | grep enabled
systemctl --failed                      # unités en échec : premier réflexe de diagnostic
systemctl list-dependencies nginx       # arbre de dépendances
systemctl cat nginx                     # affiche l'unité + drop-ins effectifs
systemctl show nginx -p MainPID,ActiveState,ExecStart,Restart
systemctl get-default ; sudo systemctl set-default multi-user.target
sudo systemctl daemon-reload            # relire les fichiers d'unités (OBLIGATOIRE après modification)
sudo systemctl reboot ; sudo systemctl poweroff ; sudo systemctl isolate rescue.target
```

**start vs enable** : `start` agit *maintenant*, `enable` agit *au prochain démarrage*. Un service peut être actif mais non activé, et inversement.

Lire `systemctl status` :

```text
● nginx.service - A high performance web server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Mon 2024-03-11 10:00:12 UTC; 2h ago
    Process: 812 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
   Main PID: 815 (nginx)
      Tasks: 3 (limit: 4557)
     Memory: 5.1M
        CPU: 128ms
     CGroup: /system.slice/nginx.service
             ├─815 "nginx: master process /usr/sbin/nginx"
             └─816 "nginx: worker process"
Mar 11 10:00:12 srv systemd[1]: Started nginx.service
```

États : `active (running)`, `active (exited)` (oneshot terminé), `inactive (dead)`, `failed`, `activating (auto-restart)`.

## 3. Écrire une unité de service

Emplacement : **`/etc/systemd/system/`** (vos unités, prioritaires). `/usr/lib/systemd/system/` appartient aux paquets : ne l'éditez pas.

`/etc/systemd/system/monapp.service` :

```ini
[Unit]
Description=Mon application web
Documentation=https://wiki.example.org/monapp
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=simple
User=monapp
Group=monapp
WorkingDirectory=/opt/monapp
EnvironmentFile=-/etc/monapp/env
Environment=PORT=8080
ExecStartPre=/opt/monapp/bin/check-config
ExecStart=/opt/monapp/bin/monapp --port ${PORT}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=3
TimeoutStopSec=30
LimitNOFILE=65535

# Durcissement
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
ReadWritePaths=/var/lib/monapp
CapabilityBoundingSet=
SystemCallFilter=@system-service

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now monapp
systemd-analyze verify /etc/systemd/system/monapp.service      # vérifie la syntaxe/les chemins
systemd-analyze security monapp.service                        # note d'exposition (0 = sûr … 10 = exposé)
```

### Les directives à connaître

**`[Unit]` — dépendances et ordre** (deux notions indépendantes !)

| Directive | Sens |
|-----------|------|
| `Wants=` | dépendance **faible** (démarre aussi, tolère l'échec) |
| `Requires=` | dépendance **forte** (si absent/échec, cette unité échoue) |
| `After=` / `Before=` | **ordre** seulement (n'active rien) |
| `BindsTo=`, `PartOf=` | liaison de cycle de vie |
| `Conflicts=` | exclusion mutuelle |
| `OnFailure=` | unité à lancer en cas d'échec (ex. notification) |

**`[Service]`**

| Directive | Valeurs / sens |
|-----------|----------------|
| `Type=simple` | (défaut) le processus de `ExecStart` *est* le service |
| `Type=forking` | le programme se détache (démon classique) ; ajouter `PIDFile=` |
| `Type=oneshot` | exécute une tâche puis se termine (scripts, sauvegardes) ; `RemainAfterExit=yes` |
| `Type=notify` | le service prévient systemd quand il est prêt (sd_notify) |
| `Restart=` | `no` · `on-failure` · `on-abnormal` · `always` ; `RestartSec=` délai |
| `User=`, `Group=` | identité d'exécution (jamais root si possible) ; `DynamicUser=yes` crée un compte temporaire |
| `ExecStart/Stop/Reload/StartPre/StartPost=` | commandes (chemins **absolus**) ; préfixe `-` : ignorer l'échec |
| `Environment=`, `EnvironmentFile=` | variables |
| `WorkingDirectory=`, `StateDirectory=`, `LogsDirectory=` | crée `/var/lib/NOM`, `/var/log/NOM` avec les bons droits |
| `TimeoutStartSec/StopSec=` | délais avant SIGKILL |
| `StandardOutput=` | `journal` (défaut), `file:/chemin`, `null` |

**Durcissement** : `NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`, `ProtectSystem=strict|full`, `ProtectHome`, `ReadOnlyPaths`, `ReadWritePaths`, `RestrictAddressFamilies`, `CapabilityBoundingSet`, `SystemCallFilter`, `MemoryDenyWriteExecute`. Mesurez avec `systemd-analyze security`.

### Modifier un service existant sans toucher au fichier d'origine : *drop-in*

```bash
sudo systemctl edit nginx            # crée /etc/systemd/system/nginx.service.d/override.conf
# [Service]
# Restart=always
# LimitNOFILE=100000
sudo systemctl edit --full nginx     # copie complète
sudo systemctl revert nginx          # supprime les surcharges
```
Pour **vider** une liste (ex. `ExecStart=`), mettre d'abord une ligne vide `ExecStart=` puis la nouvelle valeur.

## 4. Journaux avec journald

`journald` collecte stdout/stderr des services, `syslog`, le noyau. Format binaire indexé.

```bash
journalctl                                  # tout (ancien → récent)
journalctl -e                               # va à la fin
journalctl -f                               # suivre en direct (≈ tail -f)
journalctl -u nginx                         # un service
journalctl -u nginx -u php8.2-fpm --since "1 hour ago"
journalctl --since "2024-03-11 10:00" --until "2024-03-11 11:00"
journalctl -b                               # depuis le démarrage courant ; -b -1 : le précédent
journalctl -p err                           # priorité erreur et plus grave (emerg..debug)
journalctl -k                               # messages du noyau (dmesg)
journalctl _PID=812 ; journalctl _UID=1000 ; journalctl /usr/sbin/sshd
journalctl -o json-pretty -n 1              # sortie structurée
journalctl -n 50 --no-pager | grep -i error
journalctl --disk-usage
sudo journalctl --vacuum-size=500M          # ou --vacuum-time=2weeks
```

Persistance : par défaut, le journal peut être en mémoire (`/run/log/journal`). Pour le conserver : `sudo mkdir -p /var/log/journal` (ou `Storage=persistent` dans `/etc/systemd/journald.conf`) puis `sudo systemctl restart systemd-journald`. Envoyer un message : `logger -t monscript "bonjour"` ; `systemd-cat -t tag commande`.

## 5. Dépanner un service qui ne démarre pas

```bash
systemctl status monapp                    # 1. lire l'état et le code de sortie
journalctl -xeu monapp                     # 2. logs détaillés avec explications (-x), fin (-e)
systemd-analyze verify /etc/systemd/system/monapp.service   # 3. syntaxe
sudo -u monapp /opt/monapp/bin/monapp      # 4. reproduire à la main avec le même utilisateur
systemctl show monapp -p ExecMainStatus,Result,NRestarts
```

| Symptôme | Cause fréquente |
|----------|-----------------|
| `status=203/EXEC` | `ExecStart` introuvable / non exécutable / mauvais shebang / SELinux |
| `status=200/CHDIR` | `WorkingDirectory` absent |
| `status=217/USER` | `User=` inexistant |
| `status=226/NAMESPACE` | options de sandboxing incompatibles (chemins `ReadWritePaths` absents) |
| `start request repeated too quickly` | boucle de crash ; `systemctl reset-failed` après correction |
| Les changements ne s'appliquent pas | oubli de `daemon-reload` |
| Le service s'arrête à la fermeture de SSH | lancé hors systemd : créez une unité |

## 6. Planification : cron

`cron` exécute des commandes à intervalles réguliers (démon `cron`, ou `crond` sous RHEL).

```text
 ┌──────────── minute (0-59)
 │ ┌────────── heure (0-23)
 │ │ ┌──────── jour du mois (1-31)
 │ │ │ ┌────── mois (1-12 ou jan-dec)
 │ │ │ │ ┌──── jour de la semaine (0-7 ou sun-sat ; 0 et 7 = dimanche)
 │ │ │ │ │
 * * * * *  commande
```

| Expression | Signification |
|-----------|---------------|
| `*/15 * * * *` | toutes les 15 minutes |
| `30 2 * * *` | tous les jours à 02:30 |
| `0 8 * * 1-5` | du lundi au vendredi à 08:00 |
| `0 0 1 * *` | le 1ᵉʳ de chaque mois à minuit |
| `0 23 * * 0` | le dimanche à 23:00 |
| `@reboot` / `@daily` / `@hourly` / `@weekly` / `@monthly` | raccourcis |

```bash
crontab -e                  # édite la crontab de l'utilisateur courant
crontab -l                  # liste
sudo crontab -u alice -l
```
Fichiers système : `/etc/crontab` et `/etc/cron.d/*` (**avec** un champ utilisateur avant la commande), et dossiers `/etc/cron.hourly|daily|weekly|monthly/` (scripts exécutables, sans extension).

```cron
# /etc/cron.d/sauvegarde
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO=admin@example.org
30 2 * * * root /usr/local/bin/sauvegarde.sh >> /var/log/sauvegarde.log 2>&1
```

Pièges de cron : environnement **minimal** (PATH réduit, pas de `~/.bashrc`) → chemins absolus ; `%` à échapper (`\%`) ; sortie envoyée par mail si non redirigée ; pas de rattrapage si la machine était éteinte (→ `anacron` ou timers `Persistent=true`) ; tâches qui se chevauchent (→ `flock -n /var/lock/x.lock cmd`). `at` exécute une commande **une seule fois** (`echo cmd | at 18:00`, `atq`).

## 7. Timers systemd (alternative moderne à cron)

Avantages : journalisation (`journalctl -u`), dépendances, limites de ressources, rattrapage (`Persistent=`), délai aléatoire (`RandomizedDelaySec=`), observation (`systemctl list-timers`).

`/etc/systemd/system/sauvegarde.service` :

```ini
[Unit]
Description=Sauvegarde quotidienne

[Service]
Type=oneshot
ExecStart=/usr/local/bin/sauvegarde.sh
Nice=10
IOSchedulingClass=idle
```

`/etc/systemd/system/sauvegarde.timer` :

```ini
[Unit]
Description=Planification de la sauvegarde

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now sauvegarde.timer      # on active le TIMER, pas le service
systemctl list-timers --all
sudo systemctl start sauvegarde.service           # lancer la tâche à la main
journalctl -u sauvegarde.service
systemd-analyze calendar "Mon..Fri 08:00" --iterations=3      # valider une expression
```

Syntaxe `OnCalendar` : `DOW AAAA-MM-JJ HH:MM:SS` ; exemples : `hourly`, `daily`, `weekly`, `*-*-01 00:00`, `Mon..Fri 08:00`, `*:0/15` (toutes les 15 min). Timers **monotones** : `OnBootSec=5min`, `OnUnitActiveSec=1h` (répétition après la dernière exécution).

## 8. Autres outils

```bash
systemd-run --unit=test --on-active=30s /usr/bin/touch /tmp/x    # timer transitoire
sudo systemd-run --scope -p MemoryMax=500M -p CPUQuota=50% commande      # limites de ressources via cgroups
systemctl set-property nginx.service MemoryMax=1G CPUQuota=200%         # persistant (drop-in auto)
systemd-cgls ; systemd-cgtop                                           # arbre cgroups / consommation
systemd-analyze                     # temps de démarrage total
systemd-analyze blame | head        # unités les plus lentes
systemd-analyze critical-chain      # chaîne critique
hostnamectl ; timedatectl ; localectl ; loginctl list-sessions
timedatectl set-timezone Europe/Paris ; timedatectl set-ntp true
```

**Services utilisateur** : `systemctl --user enable --now monservice` (unités dans `~/.config/systemd/user/`) ; `loginctl enable-linger alice` pour qu'ils tournent sans session ouverte.

**Activation par socket** : `monapp.socket` écoute, systemd démarre `monapp.service` à la première connexion (économie de ressources, redémarrage sans perte de connexions).

## 9. Mode secours

Au démarrage, dans GRUB : touche `e`, ajouter `systemd.unit=rescue.target` (ou `emergency.target`, ou `init=/bin/bash` en dernier recours) puis `Ctrl+X`. Cas typique : un `fstab` cassé → corriger en mode d'urgence, `mount -o remount,rw /`, `systemctl daemon-reload`. Réinitialiser le mot de passe root : voir module 21.

## 10. Résumé

- systemd = PID 1, unités (`service`, `timer`, `target`, `mount`…), cgroups, journald.
- `systemctl start|stop|restart|reload|enable --now|status|--failed`, **`daemon-reload`** après édition.
- Unité de service : `[Unit]` (After/Wants/Requires) · `[Service]` (Type, User, ExecStart, Restart, durcissement) · `[Install]` (WantedBy).
- `systemctl edit` = drop-in ; `systemd-analyze verify|security|blame`.
- `journalctl -u UNITÉ -f / -b / --since / -p err`.
- Planification : cron (5 champs) ou **timer** (`OnCalendar`, `Persistent`) + service `oneshot`.

## 11. Quiz

1. Quelle différence entre `restart` et `reload` ? Entre `start` et `enable` ?
2. Où placez-vous vos propres unités et que faire après les avoir créées ?
3. `After=` suffit-il à démarrer la base de données avant l'application ? Sinon, que faut-il ajouter ?
4. Quelle expression cron exécute un script du lundi au vendredi à 18:45 ?
5. Quel est l'équivalent timer systemd de `30 2 * * *` ?
6. Comment voir les logs de `nginx` depuis 1 h et suivre les nouveaux ?
7. Un service affiche `status=203/EXEC` : que vérifiez-vous ?
8. Pourquoi un script cron qui marche à la main peut-il échouer en cron ?

<details><summary>Réponses</summary>

1. `restart` stoppe puis relance (coupure) ; `reload` demande au service de relire sa config. `start` démarre maintenant ; `enable` programme le démarrage au boot.
2. `/etc/systemd/system/` ; puis `sudo systemctl daemon-reload` (et `enable --now`).
3. Non, `After=` n'ordonne qu'entre unités démarrées. Ajouter `Requires=`/`Wants=` pour déclencher aussi son démarrage.
4. `45 18 * * 1-5 /chemin/script.sh`
5. `OnCalendar=*-*-* 02:30:00` (dans un `.timer` lié à un `.service`).
6. `journalctl -u nginx --since "1 hour ago" -f`
7. Que `ExecStart` pointe un binaire existant, exécutable, avec un shebang valide, et les droits/SELinux.
8. Environnement minimal (PATH, variables), chemins relatifs, répertoire courant, pas de terminal, `%` non échappé.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 14` · **Suivant** : [15 — Journaux, archivage et sauvegardes](../15-journaux-et-archivage/README.md)
