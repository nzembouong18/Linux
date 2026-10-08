# Projet final — Mise en production de l'application « Tickets »

> **Durée** : 12 à 16 h (1 à 2 jours en autonomie ou en binôme) · **Difficulté** : ⭐⭐⭐⭐⭐ · **Prérequis** : modules 01 à 24
> Tout le livrable est du **code et de la documentation** dans `~/labs/25/livrable/`. L'application est fournie (`app/app.py`) et déjà lancée en local pour vos tests ; les déploiements se font dans une **maquette** (`cible/`) afin de ne rien toucher au système réel.

## Contexte

Votre équipe reprend l'application web **Tickets** (Python, stdlib). Elle doit être mise en production sur un serveur Ubuntu 24.04 en respectant les standards de l'entreprise : service durci géré par systemd, reverse proxy nginx, sauvegardes vérifiées avec rétention, supervision, pare-feu et durcissement SSH/noyau, **déploiement automatisé et idempotent avec Ansible**, secrets chiffrés, et dossier d'exploitation (README, runbook, PRA). Le correcteur automatique **exécute vos scripts, démarre nginx devant l'application et rejoue votre playbook** ; un jury évalue ensuite la qualité, la soutenance et la capacité à restaurer un service en direct.

## Mise en place

```bash
./lab setup 25
cd ~/labs/25 && cat ports.txt && ls -a
```

- `ports.txt` : `APP_PORT` (l'application écoute sur `127.0.0.1:APP_PORT`) et `WEB_PORT` (port d'écoute que doit utiliser **votre nginx**).
- `app/app.py` : l'application. Points d'accès : `/` (HTML `<h1>Tickets</h1>`), `/health` (`ok`), `/api/tickets` (JSON), `/whoami` (en-têtes reçus), `/slow?ms=N`, `/error` (500).
- `.vault_pass` : mot de passe Ansible Vault du projet (**jamais** versionné).
- `GRILLE_EVALUATION.md` : la grille de notation du jury (lisez-la d'abord !).

## Arborescence du livrable (chemins imposés)

```text
livrable/
├── systemd/tickets.service
├── nginx/tickets.conf
├── scripts/{backup.sh,healthcheck.sh}
├── security/{nftables.conf,sshd_99-tickets.conf,sysctl.conf}
├── ansible/{inventaire.ini,site.yml,templates/*,group_vars/all/vault.yml}   (+ ansible.cfg facultatif)
├── docs/{README.md,RUNBOOK.md,PRA.md}
└── .gitignore
```

## Cahier des charges

### 1. `systemd/tickets.service`
`Description`, `After=network.target` · `ExecStart=/usr/bin/python3 /opt/tickets/app.py` · `WorkingDirectory=/opt/tickets` · utilisateur **non-root** (`User=tickets` ou `DynamicUser=yes`) · `Restart=on-failure` (ou `always`) avec `RestartSec` de 1 à 30 s · `EnvironmentFile=/etc/tickets/tickets.env` (le `-` initial est toléré) · au moins **6 directives de durcissement** (`NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`, `ProtectSystem`, `ProtectHome`, `ProtectKernelTunables`, `ProtectControlGroups`, `RestrictAddressFamilies`, `CapabilityBoundingSet`, `MemoryMax`, `TasksMax`, `LimitNOFILE`) · `WantedBy=multi-user.target`. Doit passer `systemd-analyze verify`.

### 2. `nginx/tickets.conf` — fichier **inclus dans le contexte `http {}`**
Un `upstream`, un `server` écoutant sur `127.0.0.1:WEB_PORT` (valeur de `ports.txt`) et un reverse proxy vers `127.0.0.1:APP_PORT` :
- `server_tokens off` ; en-têtes `X-Content-Type-Options: nosniff` et `X-Frame-Options: DENY` (directive `always`) ;
- transmission de `Host` (`$http_host`) et `X-Forwarded-For` (`$remote_addr`) ;
- **gzip** pour `application/json` ;
- **limite de débit** sur `/api/` : 5 requêtes/seconde/IP, rafale (`burst`) 5, refus avec le statut **429** ;
- journal d'accès **dédié** `logs/tickets-access.log` (chemin relatif au préfixe) avec un format contenant `rt=$request_time` et `up=$upstream_addr`.

### 3. `scripts/backup.sh [-n KEEP] [--dry-run] SRC DEST`
- crée `DEST/tickets-<horodatage>.tar.gz` (horodatage `AAAAMMJJ-HHMMSS`, ou la valeur de la variable d'environnement `BACKUP_STAMP` si elle est définie) contenant le **dossier** `SRC` ; vérifie l'archive (`tar -tzf`) ;
- ajoute la ligne d'empreinte dans `DEST/SHA256SUMS` (`sha256sum -c` doit réussir depuis `DEST`) ;
- **rétention** : ne garde que les `KEEP` archives les plus récentes (défaut **7**) et retire les lignes correspondantes de `SHA256SUMS` ;
- `--dry-run` : affiche `DRY-RUN: …` et ne crée rien ;
- **stdout** : uniquement le chemin de l'archive créée ; erreurs sur stderr ;
- codes retour : `0` succès · `1` usage (arguments manquants, `-n` invalide) · `3` source absente · `4` destination inutilisable · `5` archive illisible.

### 4. `scripts/healthcheck.sh -u URL [-t TIMEOUT_S] [-w WARN_MS] [-c CRIT_MS]`
Plugin de supervision (contrat Nagios), défauts : timeout 5 s, `w`=500, `c`=1000 :
- `HTTP OK - 200 in <N>ms|time=<N>ms;<w>;<c>;0` (code 0) si statut 200 et durée < `w` ;
- `HTTP WARNING - …` (code 1) si durée ≥ `w` ; `HTTP CRITICAL - …` (code 2) si durée ≥ `c`, statut ≠ 200, connexion impossible ou délai dépassé ;
- `HTTP UNKNOWN - …` (code 3) si `-u` manquant, valeurs non numériques ou `w ≥ c`.

### 5. Sécurité
- `security/nftables.conf` : chaîne `input` en `policy drop` ; `established,related` et loopback acceptés ; SSH (22) **limité à des adresses d'administration** (`ip saddr`) ; HTTP/HTTPS (80, 443) ; ping limité (`limit rate`) ; **le port applicatif `APP_PORT` ne doit jamais être ouvert**. Doit passer `nft -c -f`.
- `security/sshd_99-tickets.conf` : `PermitRootLogin no`, `PasswordAuthentication no`, `MaxAuthTries` ≤ 4, `X11Forwarding no`, `AllowUsers` ou `AllowGroups`.
- `security/sysctl.conf` : `tcp_syncookies=1`, `rp_filter=1`, `accept_redirects=0`, `send_redirects=0`, `randomize_va_space=2`, `kptr_restrict`≥1, `yama.ptrace_scope`≥1, `fs.protected_symlinks=1`, `fs.protected_hardlinks=1`.

### 6. Ansible (`ansible/`)
Le correcteur lance, depuis `livrable/ansible/` :
`ansible-playbook -i inventaire.ini site.yml --vault-password-file ../../.vault_pass -e target_root=<labo>/cible -e app_port=<APP_PORT>`
Le playbook (hôte local, `ansible_connection=local`) déploie dans `{{ target_root }}` :

| Source | Destination (sous `target_root`) | Mode |
|--------|----------------------------------|:----:|
| `systemd/tickets.service` | `etc/systemd/system/tickets.service` | 0644 |
| `nginx/tickets.conf` | `etc/nginx/conf.d/tickets.conf` | 0644 |
| `scripts/backup.sh` | `usr/local/bin/tickets-backup` | 0755 |
| `scripts/healthcheck.sh` | `usr/local/bin/tickets-healthcheck` | 0755 |
| `security/sshd_99-tickets.conf` | `etc/ssh/sshd_config.d/99-tickets.conf` | 0644 |
| `security/nftables.conf` | `etc/nftables.conf` | 0600 |
| `security/sysctl.conf` | `etc/sysctl.d/99-tickets.conf` | 0644 |
| **gabarit** `templates/…` | `etc/tickets/tickets.env` | 0640 |

- `tickets.env` contient `PORT=<app_port>` et `SECRET_KEY=<valeur>`, la valeur venant de `vault_secret_key` stockée dans **`group_vars/all/vault.yml` chiffré** avec `.vault_pass`.
- **Handlers** : un changement de l'unité écrit `var/run/systemd-reload.flag`, un changement de la conf nginx écrit `var/run/nginx-reload.flag` (sous `target_root`).
- **Idempotence** : après un premier passage, un second ne doit produire **aucun changement** et aucun handler.

### 7. Documentation (`docs/`)
- `README.md` : sections **Architecture** (avec un schéma en bloc de code), **Installation**, **Exploitation** ; ≥ 150 mots ; cite nginx, systemd et la sauvegarde.
- `RUNBOOK.md` : **≥ 3 incidents** (titres `##`), chacun avec **Diagnostic** et **Actions** et des commandes concrètes (`journalctl`, `systemctl`, `ss`…) ; ≥ 250 mots.
- `PRA.md` : **RPO et RTO chiffrés**, procédure de restauration, **tests de restauration**, contacts ; ≥ 200 mots.

### 8. Hygiène
`.gitignore` (au minimum `*.env`, `.vault_pass`, `cible/`) · aucune clé privée ni secret en clair dans `livrable/` · tout fichier `vault*.yml` est chiffré.

## Validation automatique

```bash
./lab check 25        # exécute scripts, nginx, ansible : ~1 minute
```
Les résultats sont groupés par section (1 à 8). **Objectif : 100 % des points automatiques** avant la soutenance.

## Soutenance (jury) — 30 min

1. **Présentation** (10 min) : architecture, choix, difficultés, ce qu'on referait différemment.
2. **Démonstration** (10 min) : déploiement Ansible depuis zéro, panne simulée (`kill -9` du service, disque plein, sauvegarde corrompue), restauration **chronométrée**.
3. **Questions** (10 min) : sécurité, idempotence, choix de rétention, évolution (TLS, haute disponibilité, supervision Prometheus).
Voir la grille dans `GRILLE_EVALUATION.md` (copie de [grille-evaluation.md](grille-evaluation.md)).

<details><summary>💡 Conseils de démarche</summary>

1. Commencez par `docs/` (plan, architecture) puis les scripts (testables seuls), puis nginx, puis l'unité, puis Ansible en dernier : il assemble tout.
2. Testez chaque brique isolément (`nginx -t`, `systemd-analyze verify`, `bash -n`, `shellcheck`, `nft -c`, `ansible-playbook --syntax-check`) avant `./lab check 25`.
3. Faites des commits fréquents (git) et relisez-vous : le jury lit le code.
4. Ne copiez pas la solution de référence : comprenez-la une fois votre version terminée (comparez les différences).
</details>

<details><summary>🛟 Solution de référence</summary>

`./lab solve 25` dépose une solution complète dans `~/labs/25/livrable` (code source dans `modules/25-projet-final/solution/livrable/`). À consulter **après** votre tentative.
</details>

## Nettoyage

```bash
./lab reset 25     # arrête l'application et nginx de test
```
