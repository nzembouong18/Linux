# Module 07 — Processus, signaux et tâches de fond

> **Niveau** : Intermédiaire | **Durée** : 3 h (1 h 30 cours + 1 h 30 labo) | **Prérequis** : modules 02–06
>
> **Objectifs** — À la fin de ce module vous saurez :
> - expliquer ce qu'est un processus (PID, PPID, états, `fork`/`exec`) ;
> - observer l'activité du système (`ps`, `top`, `htop`, `pstree`, `/proc`) ;
> - envoyer des signaux (`kill`, `pkill`) et écrire un script qui les gère (`trap`) ;
> - gérer premier plan / arrière-plan, `nohup`, `tmux` ;
> - régler les priorités (`nice`, `renice`) et diagnostiquer zombies et processus bloqués.

---

## 1. Qu'est-ce qu'un processus ?

Un **programme** est un fichier sur le disque ; un **processus** est une **instance en cours d'exécution** de ce programme, avec :

- un identifiant **PID** et un parent **PPID** ;
- un propriétaire (UID/GID) ;
- sa mémoire, ses descripteurs de fichiers ouverts, son répertoire courant, son environnement ;
- un état d'ordonnancement.

Tout démarre avec le processus **PID 1** (`systemd` ou `init`), ancêtre de tous les autres. Un nouveau processus naît par **`fork()`** (clonage du parent) puis **`exec()`** (remplacement du code par un autre programme) :

```text
bash (PID 800)
  │ fork()
  ├──► bash (PID 901, copie)
  │        │ exec("/bin/ls")
  │        └──► ls (PID 901)  ... fin  → exit(0)
  │ wait() récupère le code retour
  ▼
bash continue
```

### États d'un processus (`STAT` dans `ps`)

| Code | État | Signification |
|:---:|------|---------------|
| **R** | Running | en cours d'exécution ou prêt |
| **S** | Sleeping | attend un événement (réseau, clavier…) — état normal |
| **D** | Uninterruptible sleep | attend le matériel (I/O disque/NFS) ; **ne répond pas aux signaux** |
| **T** | Stopped | suspendu (`Ctrl+Z`, SIGSTOP) |
| **Z** | Zombie | terminé, mais le parent n'a pas encore lu son code retour |
| `<` `N` `s` `l` `+` | priorité haute, basse, chef de session, multithread, avant-plan | |

- **Zombie** : n'utilise plus de mémoire, occupe seulement une entrée de la table. Ne se « tue » pas : il faut corriger/terminer le **parent**.
- **Orphelin** : le parent est mort ; il est adopté par PID 1.
- **État D persistant** : signe d'un problème de stockage/NFS ; seul un redémarrage ou la résolution du matériel le débloque.

## 2. Observer les processus

```bash
ps                         # processus de ce terminal
ps aux                     # TOUS les processus (style BSD) : USER PID %CPU %MEM VSZ RSS STAT START TIME COMMAND
ps -ef                     # style Unix : UID PID PPID C STIME TTY TIME CMD
ps -ef --forest            # avec la hiérarchie
ps -eo pid,ppid,user,ni,stat,%cpu,%mem,cmd --sort=-%mem | head    # colonnes choisies, tri
ps -p 1234 -o pid,etime,cmd                # un PID précis, durée écoulée
pstree -p                  # arbre complet avec PID
pgrep nginx ; pgrep -a -u alice python     # PID par nom (-a : ligne de commande)
```

### `top` et `htop`

```bash
top             # interactif : P (tri CPU)  M (mémoire)  k (kill)  1 (par cœur)  q (quitter)
htop            # plus ergonomique : F6 tri, F9 kill, F5 arbre, / recherche
top -b -n1 | head -15       # mode batch : utilisable dans un script
```

En-tête de `top` :

```text
top - 10:42:01 up 3 days,  load average: 0.52, 0.40, 0.35
Tasks: 210 total,   1 running, 209 sleeping,   0 stopped,   0 zombie
%Cpu(s):  3.0 us,  1.0 sy,  0.0 ni, 95.5 id,  0.3 wa,  0.0 hi,  0.2 si
MiB Mem :  7940 total,  3200 free,  2100 used,  2640 buff/cache
```

`us` utilisateur · `sy` noyau · `ni` priorité modifiée · `id` inactif · **`wa` attente I/O** (élevé ⇒ disque lent) · `st` volé par l'hyperviseur.

### `/proc` : la vérité de chaque processus

```bash
ls /proc/$$                    # $$ = PID du shell courant
cat /proc/$$/cmdline | tr '\0' ' '     # ligne de commande
ls -l /proc/$$/cwd /proc/$$/exe        # répertoire courant et exécutable
ls -l /proc/$$/fd                      # fichiers ouverts
cat /proc/$$/status | head -12         # état, mémoire, UID
cat /proc/loadavg /proc/meminfo
```

### Qui utilise quoi ?

```bash
lsof -p 1234                 # fichiers ouverts par un processus
lsof -i :80                  # qui écoute sur le port 80 ?
lsof +L1                     # fichiers supprimés mais encore ouverts (disque « plein » fantôme)
fuser -v /var/log/syslog     # processus utilisant un fichier
ss -tulpn                    # sockets et processus associés (module 11)
```

## 3. Les signaux

Un **signal** est une notification asynchrone envoyée à un processus. Le processus peut l'intercepter (sauf `SIGKILL` et `SIGSTOP`), l'ignorer ou subir l'action par défaut.

| N° | Nom | Défaut | Usage |
|---:|-----|--------|-------|
| 1 | **SIGHUP** | terminer | terminal fermé ; beaucoup de démons **rechargent leur config** |
| 2 | **SIGINT** | terminer | `Ctrl+C` |
| 3 | SIGQUIT | terminer + core | `Ctrl+\` |
| 9 | **SIGKILL** | terminer | **non interceptable**, tue immédiatement sans nettoyage |
| 10/12 | SIGUSR1/2 | terminer | définis par l'application (ex. réouverture des logs) |
| 15 | **SIGTERM** | terminer | **demande d'arrêt propre** (signal par défaut de `kill`) |
| 17 | SIGCHLD | ignoré | un enfant a changé d'état |
| 18 | **SIGCONT** | reprendre | reprend un processus stoppé |
| 19 | **SIGSTOP** | stopper | **non interceptable** |
| 20 | SIGTSTP | stopper | `Ctrl+Z` |

```bash
kill -l                      # liste des signaux
kill 1234                    # SIGTERM (15) : demande polie
kill -9 1234                 # SIGKILL : dernier recours
kill -HUP $(pgrep nginx)     # recharge (ou: systemctl reload nginx)
kill -STOP 1234 ; kill -CONT 1234     # pause / reprise
pkill -f "python app.py"     # par motif sur la ligne de commande
pkill -u alice               # tous les processus d'alice
killall nginx                # par nom exact
kill -0 1234 && echo "existe"   # signal 0 : teste simplement l'existence
```

> **Procédure d'arrêt recommandée** : `SIGTERM` → attendre 10–30 s → seulement ensuite `SIGKILL`. Un `kill -9` systématique laisse des fichiers temporaires, verrous, transactions incomplètes.

### Intercepter les signaux dans un script : `trap`

```bash
#!/usr/bin/env bash
tmp=$(mktemp)
cleanup() { echo "Nettoyage…"; rm -f "$tmp"; exit 0; }
trap cleanup TERM INT        # exécute cleanup à la réception de SIGTERM/SIGINT
trap 'echo recharge' HUP
trap 'rm -f "$tmp"' EXIT     # toujours exécuté à la sortie du script
while true; do sleep 1; done
```

## 4. Premier plan, arrière-plan, jobs

```bash
sleep 300 &            # lance en arrière-plan ; affiche [1] 4321
jobs -l                # liste des jobs du shell (numéro, PID, état)
fg %1                  # ramène le job 1 au premier plan
Ctrl+Z                 # suspend le job de premier plan
bg %1                  # le relance en arrière-plan
kill %1                # tue le job 1
echo $!                # PID du dernier processus lancé en arrière-plan
wait $!                # attend sa fin
```

Un job d'arrière-plan reçoit `SIGHUP` quand le terminal se ferme. Solutions :

| Outil | Usage |
|-------|-------|
| `nohup commande > out.log 2>&1 &` | ignore SIGHUP, sortie dans `out.log` |
| `disown -h %1` | détache un job déjà lancé |
| `setsid commande &` | nouvelle session, indépendante du terminal |
| **`tmux`** / `screen` | **sessions persistantes** : recommandé sur un serveur distant |
| `systemd-run --user --scope commande` ou un service systemd | pour du durable (module 14) |

### tmux en 1 minute

```bash
tmux new -s travail         # nouvelle session
# Ctrl+b puis d             → détacher (le programme continue)
tmux ls                     # lister
tmux attach -t travail      # se rattacher (même après déconnexion SSH)
# Ctrl+b %  / "             → diviser verticalement / horizontalement ;  Ctrl+b flèches : naviguer
# Ctrl+b c / n / p          → nouvelle fenêtre / suivante / précédente
```

## 5. Priorités : `nice` et `renice`

La **niceness** va de **−20** (prioritaire) à **+19** (très gentil). Par défaut 0. Seul root peut baisser la valeur.

```bash
nice -n 10 tar czf backup.tgz /data      # lance avec priorité réduite
renice -n 5 -p 1234                       # change un processus existant
renice -n -5 -u postgres                  # (root) priorité pour un utilisateur
ionice -c3 -p 1234                        # classe I/O « idle »
ps -o pid,ni,cmd -p 1234
```

Pour limiter ressources de façon contraignante (CPU, RAM) on utilise les **cgroups** (modules 14 et 20) ; `ulimit` fixe des limites par shell :

```bash
ulimit -a             # toutes les limites
ulimit -n 4096        # nombre de fichiers ouverts
```

## 6. Observer dans le temps

```bash
watch -n 2 'ps aux --sort=-%cpu | head -5'     # rafraîchit toutes les 2 s
time ./commande                                # durée réelle / CPU utilisateur / système
uptime ; cat /proc/loadavg                     # charge moyenne 1/5/15 min
vmstat 1 5                                     # CPU, mémoire, swap, I/O (module 18)
```

## 7. Diagnostiquer

| Symptôme | Démarche |
|----------|----------|
| Machine lente | `uptime` (charge vs nombre de cœurs `nproc`) → `top` (`us`, `sy`, `wa`) |
| Un processus ne s'arrête pas avec `kill` | `ps -o stat` : état `D` ? sinon `kill -9` après `SIGTERM` |
| Zombies | `ps -eo pid,ppid,stat,cmd \| awk '$3 ~ /Z/'` → agir sur le **PPID** |
| « Port déjà utilisé » | `ss -tulpn \| grep :8080` ou `lsof -i :8080` |
| Disque plein mais `du` ne voit rien | `lsof +L1` : fichier supprimé mais ouvert → redémarrer le processus |
| Qui a lancé ça ? | `ps -o pid,ppid,user,lstart,cmd -p PID` ; `pstree -ps PID` |

## 8. Résumé

- Processus = programme en exécution (PID, PPID, état) ; création `fork` + `exec`.
- Observer : `ps aux`, `ps -ef --forest`, `top/htop`, `pgrep`, `/proc/<PID>`, `lsof`.
- Signaux : **TERM (15)** d'abord, **KILL (9)** en dernier recours, **HUP** pour recharger, **STOP/CONT** pour suspendre.
- Arrière-plan : `&`, `jobs`, `fg`, `bg`, `nohup`, **tmux**.
- Priorité : `nice` / `renice` (−20 à +19). Zombie ⇒ traiter le parent.

## 9. Quiz

1. Quelle est la différence entre SIGTERM et SIGKILL ?
2. Comment relancer en arrière-plan un job suspendu avec `Ctrl+Z` ?
3. Que signifie l'état `Z` ? Peut-on le tuer avec `kill -9` ?
4. Quelle commande lance `backup.sh` avec la priorité la plus basse ?
5. Votre session SSH tombe et tue votre traitement de 3 h : que faire la prochaine fois ?
6. Comment savoir quel processus écoute sur le port 5432 ?
7. À quoi sert `kill -0 PID` ?
8. Pourquoi `trap` ne peut-il pas intercepter SIGKILL ?

<details><summary>Réponses</summary>

1. SIGTERM (15) demande un arrêt propre (interceptable) ; SIGKILL (9) est imposé par le noyau, sans nettoyage.
2. `bg %1` (ou simplement `bg`).
3. Zombie : terminé mais non « récolté » par son parent. Non — il est déjà mort ; il faut que le parent fasse `wait()` ou le tuer.
4. `nice -n 19 ./backup.sh`
5. `tmux`/`screen`, ou `nohup … &`, ou un service/timer systemd.
6. `ss -tulpn | grep :5432` ou `lsof -i :5432`.
7. Teste l'existence du processus et le droit de lui envoyer un signal, sans en envoyer.
8. C'est le noyau qui le traite directement : le processus n'a aucune chance d'exécuter du code.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 07` · **Suivant** : [08 — Gestion des paquets](../08-gestion-des-paquets/README.md)
