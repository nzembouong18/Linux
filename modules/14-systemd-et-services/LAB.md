# Labo 14 — Écrire un service, un timer et planifier des tâches

> **Durée** : 3 h · **Difficulté** : ⭐⭐⭐ · **Prérequis** : module 14 · outil : `systemd-analyze`
> Les fichiers d'unités sont **écrits dans le dossier du labo** et validés avec `systemd-analyze verify` : pas besoin de systemd en PID 1 pour réussir. Une partie « bonus » sur VM/conteneur systemd est proposée à la fin.

## Contexte

Votre équipe déploie une petite API (`bin/api.sh`) et une sauvegarde nocturne (`bin/sauvegarde.sh`). Il faut les confier à systemd : l'API doit **redémarrer toute seule** et tourner **durcie**, la sauvegarde doit s'exécuter **chaque nuit à 02:30**, même si la machine était éteinte à ce moment-là. Vous documentez aussi quelques réflexes d'exploitation et écrivez des expressions cron.

## Mise en place

```bash
./lab setup 14
cd ~/labs/14 && ls -R
```

## Partie A — Le service `labapi.service`

Créez `labapi.service` (dans `~/labs/14`) avec :

- `[Unit]` : une `Description=` ; démarrage **après le réseau** (`After=network.target` ou `network-online.target`).
- `[Service]` : `Type=simple`, `ExecStart=` = chemin **absolu** de `bin/api.sh`, `Restart=on-failure`, `RestartSec=` entre 2 et 10 secondes, exécution **non-root** (`User=` autre que root, ou `DynamicUser=yes`), `Environment=PORT=8080`, et les durcissements `NoNewPrivileges=yes`, `PrivateTmp=yes`, `ProtectSystem=strict` (ou `full`).
- `[Install]` : `WantedBy=multi-user.target`.

## Partie B — Sauvegarde nocturne : service + timer

1. `labsauvegarde.service` : `Type=oneshot`, `ExecStart=` = chemin absolu de `bin/sauvegarde.sh`.
2. `labsauvegarde.timer` : déclenchement **tous les jours à 02:30** (`OnCalendar`), **rattrapage** si la machine était éteinte (`Persistent=true`), et `[Install] WantedBy=timers.target`.

## Partie C — Cron

Dans `cron.txt`, une ligne `CLÉ=expression` (5 champs cron) par besoin :

| Clé | Besoin |
|-----|--------|
| `TOUTES_15MIN` | toutes les 15 minutes |
| `QUOTIDIEN_0230` | tous les jours à 02:30 |
| `SEMAINE_0800` | du lundi au vendredi à 08:00 |
| `MENSUEL` | le 1ᵉʳ de chaque mois à minuit |
| `DIMANCHE_23H` | le dimanche à 23:00 |
| `DEUX_FOIS_PAR_JOUR` | à 07:15 et à 19:15 chaque jour |
| `CRON_LIGNE` | **ligne complète** de crontab : du lundi au vendredi à 18:45, exécute `/opt/bin/rapport.sh`, sa sortie standard **et** son erreur étant **ajoutées** à `/var/log/rapport.log` |

*(Les écritures équivalentes — `0,15,30,45`, `mon-fri`, `7` pour dimanche… — sont acceptées.)*

## Partie D — Réflexes d'exploitation (`reponses.txt`, format `CLÉ=valeur`)

| Clé | Question |
|-----|----------|
| `UNIT_ADMIN` | dossier où l'administrateur place ses unités |
| `UNIT_PAQUETS` | dossier des unités fournies par les paquets |
| `CMD_RELOAD` | commande à lancer après avoir modifié un fichier d'unité |
| `CMD_ECHECS` | commande qui liste les unités en échec |
| `CMD_LOGS_SUIVRE` | commande pour suivre en direct les journaux de `labapi.service` |
| `CMD_TIMERS` | commande qui liste les timers et leur prochaine exécution |
| `SIGNAL_ARRET` | signal envoyé par défaut par systemd pour arrêter un service |

## Validation

```bash
./lab check 14
```

<details><summary>💡 Indices</summary>

- `systemd-analyze verify ./labapi.service` (vous devez avoir un `ExecStart` valide et exécutable).
- `systemd-analyze calendar '*-*-* 02:30:00'` affiche la forme normalisée.
- Une ligne de crontab : `45 18 * * 1-5 /opt/bin/rapport.sh >> /var/log/rapport.log 2>&1`.
- `man systemd.service`, `man systemd.timer`, `man 5 crontab`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/14
cat > labapi.service <<EOF
[Unit]
Description=API du labo
After=network.target

[Service]
Type=simple
ExecStart=$PWD/bin/api.sh
Restart=on-failure
RestartSec=3
DynamicUser=yes
Environment=PORT=8080
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF
cat > labsauvegarde.service <<EOF
[Unit]
Description=Sauvegarde du labo

[Service]
Type=oneshot
ExecStart=$PWD/bin/sauvegarde.sh
EOF
cat > labsauvegarde.timer <<EOF
[Unit]
Description=Sauvegarde nocturne

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
cat > cron.txt <<'EOF'
TOUTES_15MIN=*/15 * * * *
QUOTIDIEN_0230=30 2 * * *
SEMAINE_0800=0 8 * * 1-5
MENSUEL=0 0 1 * *
DIMANCHE_23H=0 23 * * 0
DEUX_FOIS_PAR_JOUR=15 7,19 * * *
CRON_LIGNE=45 18 * * 1-5 /opt/bin/rapport.sh >> /var/log/rapport.log 2>&1
EOF
cat > reponses.txt <<'EOF'
UNIT_ADMIN=/etc/systemd/system
UNIT_PAQUETS=/usr/lib/systemd/system
CMD_RELOAD=systemctl daemon-reload
CMD_ECHECS=systemctl --failed
CMD_LOGS_SUIVRE=journalctl -u labapi.service -f
CMD_TIMERS=systemctl list-timers
SIGNAL_ARRET=SIGTERM
EOF
```
</details>

## Bonus (sur une VM ou le conteneur `lab` avec systemd, non évalué)

```bash
sudo cp labapi.service labsauvegarde.service labsauvegarde.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now labapi.service labsauvegarde.timer
systemctl status labapi ; systemctl list-timers | grep lab
sudo kill -9 "$(systemctl show -p MainPID --value labapi)"    # observez le redémarrage automatique
journalctl -u labapi -n 20 --no-pager
sudo systemctl start labsauvegarde.service && journalctl -u labsauvegarde -n 5 --no-pager
systemd-analyze security labapi.service | tail -3
sudo systemctl edit labapi    # ajoutez un drop-in : MemoryMax=100M
```

## Nettoyage

```bash
./lab reset 14
```
