# Module 18 — Performance et dépannage : méthode, outils et scénarios

> **Niveau** : Avancé | **Durée** : 7 h (3 h cours + 4 h labo) | **Prérequis** : modules 07, 13, 14
>
> **Objectifs** — À la fin de ce module vous saurez :
> - appliquer une **méthode** de diagnostic (USE, 60 secondes, hypothèse → mesure) ;
> - analyser CPU, mémoire, disque, réseau avec `vmstat`, `mpstat`, `iostat`, `pidstat`, `sar`, `free`, `ss` ;
> - comprendre **load average**, swap, cache, **OOM killer** ;
> - tracer un processus avec `strace`, `lsof`, `perf` et lire `/proc` ;
> - résoudre les pannes courantes (CPU saturé, fuite mémoire, I/O, fichiers ouverts, zombies, disque plein) ;
> - rédiger un diagnostic reproductible.

---

## 1. État d'esprit et méthode

> **Mesurer avant de modifier. Un seul changement à la fois. Noter ce qu'on fait.**

### La méthode USE (Brendan Gregg)
Pour **chaque ressource** (CPU, mémoire, disque, réseau, ventilateurs…), vérifier :

| Lettre | Question | Exemples |
|--------|----------|----------|
| **U**tilisation | quel % du temps est-elle occupée ? | CPU `us+sy`, `%util` disque |
| **S**aturation | du travail attend-il en file ? | `r` > nb cœurs (vmstat), `await` disque, swap, retransmissions |
| **E**rreurs | des erreurs sont-elles comptées ? | `dmesg`, `ip -s link`, SMART, ECC |

### Méthode scientifique
1. **Symptôme** précis (quoi, depuis quand, pour qui, quelle fréquence, qu'est-ce qui a changé ?)
2. **Hypothèse** → 3. **Mesure** qui peut l'infirmer → 4. **Correction** minimale → 5. **Vérification** → 6. **Documentation**.

### Les « 60 secondes » à la connexion (checklist)

```bash
uptime                         # 1. load average (1/5/15 min) : tendance
dmesg -T | tail                # 2. erreurs noyau récentes (OOM, I/O error, segfault)
vmstat 1 5                     # 3. r (file d'exécution), b, swap si/so, us/sy/id/wa
mpstat -P ALL 1 3              # 4. CPU par cœur : un seul cœur saturé ?
pidstat 1 3                    # 5. consommation par processus
iostat -xz 1 3                 # 6. disques : %util, await, r/s w/s
free -m                        # 7. mémoire et swap
sar -n DEV 1 3                 # 8. débit réseau par interface
sar -n TCP,ETCP 1 3            # 9. connexions, retransmissions
top                            # 10. vue d'ensemble
```

## 2. CPU

### Load average ≠ utilisation CPU

`load average` = nombre moyen de tâches **prêtes à s'exécuter ou en attente d'I/O non interruptible** (état `R` + `D`). Comparez-le au nombre de cœurs (`nproc`) :

| Machine 4 cœurs | Interprétation |
|-----------------|----------------|
| load 1.0 | 25 % de charge, confortable |
| load 4.0 | saturée (tous les cœurs occupés) |
| load 12.0 | file d'attente de 8 tâches : lenteurs |
| load élevé **et** CPU idle élevé | tâches bloquées sur I/O (état `D`) → regarder le disque/NFS |

### Lire `vmstat 1`

```text
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 9  0      0 812344  80212 912344    0    0     2     5 1204 3011 94  4  2  0  0
```
- `r` : processus prêts (file d'exécution) ; `r` > cœurs ⇒ **saturation CPU**.
- `b` : processus bloqués (I/O). `wa` : % attente d'I/O. `st` : temps volé par l'hyperviseur (VM voisines).
- `si/so` : swap in/out (**non nul en continu = pression mémoire**). `cs` : changements de contexte, `in` : interruptions.
- `us` utilisateur · `sy` noyau (trop haut ⇒ appels système/réseau/verrous) · `id` inactif.

```bash
top -o %CPU                     # touches : 1 (par cœur), H (threads), c (ligne de commande), M/P/T (tri)
pidstat -u 1 5                  # CPU par processus dans le temps
pidstat -t -p PID 1             # threads d'un processus
perf top                        # fonctions chaudes (noyau + user)
perf record -F 99 -g -p PID -- sleep 30 && perf report      # profil d'échantillonnage
```

Causes classiques : boucle infinie, GC/compilation, trop de processus/threads, tempête de logs, antivirus, cryptominer (compromission !), mauvaise requête SQL.

## 3. Mémoire

```bash
free -h
              total        used        free      shared  buff/cache   available
Mem:           7.7Gi       2.1Gi       312Mi        88Mi       5.3Gi       5.2Gi
```
- **`available`** est le bon indicateur (mémoire récupérable sans swap), pas `free`. Linux utilise la RAM libre pour le **cache disque** (`buff/cache`), libéré à la demande : « RAM presque pleine » est **normal**.
- Alarmant : `available` très bas **et** `si/so` actifs, ou `Swap used` qui grimpe.

```bash
ps aux --sort=-%mem | head              # gros consommateurs (RSS = mémoire résidente)
smem -tk 2>/dev/null | tail             # PSS : part équitable (mémoire partagée comptée proprement)
cat /proc/meminfo | egrep 'MemAvailable|Dirty|Slab|SwapCached|AnonPages'
slabtop -o | head                       # caches du noyau
cat /proc/PID/status | egrep 'VmRSS|VmSwap|Threads'
cat /proc/PID/smaps_rollup
```

### Fuite mémoire : la mémoire (RSS) d'un processus **ne cesse de croître** dans le temps

```bash
while sleep 5; do ps -o rss=,etime=,cmd= -p PID; done        # suivre la tendance
```

### Le OOM killer

Quand la mémoire est épuisée, le noyau **tue** un processus (score `oom_score`).
```bash
journalctl -k | grep -i -E 'out of memory|oom-kill|killed process'
dmesg -T | grep -i oom
cat /proc/PID/oom_score ; echo -500 | sudo tee /proc/PID/oom_score_adj     # protéger/exposer un processus
```
Limiter proprement : cgroups (`MemoryMax=` systemd, `docker run -m`), `ulimit -v`. Réglages : `vm.swappiness` (10 pour une base de données), `vm.overcommit_memory`, swap (module 13), `zram`.

## 4. Disque et I/O

```bash
iostat -xz 1 3
Device   r/s   w/s  rkB/s  wkB/s  r_await w_await aqu-sz  %util
nvme0n1  12.0 410.0  640   88000    0.30    4.10   1.80   72.0
```
- `%util` ~100 % (disque mécanique) ou `aqu-sz` élevé ⇒ **saturation**.
- `await` : latence moyenne par requête (SSD < 1 ms, HDD 5–15 ms).
- Distinguer lecture/écriture et **qui** : `sudo iotop -oPa`, `pidstat -d 1`.
- `df -h`, `df -i`, `lsof +L1` (module 13) ; SMART `smartctl -a`.
- `dd if=/dev/zero of=t bs=1M count=1000 oflag=direct` (test grossier), `fio` (sérieux).
- Écritures synchrones (`fsync`) = coût élevé : bases de données, journaux.

## 5. Réseau

```bash
sar -n DEV 1 3                         # rxkB/s txkB/s par interface
ip -s link show eth0                   # erreurs, drops, overruns
ss -s ; ss -tin dst 10.0.0.5           # états des sockets ; rtt, retrans par connexion
nstat -az | egrep 'Retrans|ListenOverflows|TCPTimeouts'
sudo tcpdump -ni eth0 -c 50 port 443
iftop -i eth0 ; nethogs                # qui consomme la bande passante
```
Pannes : **table conntrack pleine**, ports éphémères épuisés (`TIME_WAIT` massifs), fichier ouvert max atteint, DNS lent (`time getent hosts nom`), MTU.

## 6. Observer un processus : `/proc`, `lsof`, `strace`

```bash
ls -l /proc/PID/fd | wc -l             # nombre de descripteurs ouverts
cat /proc/PID/limits | grep -i 'open files'
lsof -p PID | head                     # fichiers, sockets, bibliothèques
lsof -iTCP -sTCP:ESTABLISHED -P -n
cat /proc/PID/io                       # octets lus/écrits
cat /proc/PID/stack                    # (root) pile noyau : où est-il bloqué ?
cat /proc/PID/wchan; echo
```

### `strace` : ce que fait un programme (appels système)

```bash
strace -f -tt -T -o trace.txt ./programme            # -f suit les enfants, -tt horodatage, -T durée de chaque appel
sudo strace -p PID                                   # attacher à un processus en cours (Ctrl+C pour sortir)
sudo strace -c -p PID                                # synthèse : temps par appel système (arrêter avec Ctrl+C)
strace -e trace=openat,read -s 200 commande               # filtrer / afficher plus de caractères
strace -e trace=network curl -s example.org          # seulement le réseau
strace -e trace=%file ls /nonexistent 2>&1 | tail -3
ltrace ./programme                                   # appels de bibliothèques
```

Indices : `ENOENT` (fichier absent), `EACCES` (droits), `EAGAIN`, un `read`/`futex`/`poll` qui dure longtemps (bloqué), `fsync` fréquents (lenteur d'écriture). **Attention** : `strace` ralentit fortement le processus.

### Outils modernes : `perf`, eBPF
`perf stat commande`, `perf record -g`, `bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s %s\n", comm, str(args->filename)); }'`, suite **BCC/bcc-tools** (`execsnoop`, `opensnoop`, `biolatency`, `tcpconnect`) — faible surcoût, utilisables en production.

## 7. Limites et ressources

```bash
ulimit -n                              # fichiers ouverts max (shell)
cat /proc/sys/fs/file-nr               # utilisés / alloués / max système
sysctl fs.file-max
# systemd :   LimitNOFILE=65535   dans l'unité (module 14)
# /etc/security/limits.d/90-nofile.conf :  *  soft  nofile  65535
sysctl vm.max_map_count kernel.pid_max net.core.somaxconn
```
Erreur « **Too many open files** » : fuite de descripteurs (fichiers/sockets non fermés) ou limite trop basse. Vérifier `ls /proc/PID/fd | wc -l` dans le temps.

## 8. Cas d'usage : guide de dépannage

| Symptôme | Démarche |
|----------|----------|
| **Machine lente, load élevé** | `uptime` → `vmstat` : `r` élevé = CPU ; `b`/`wa` élevés = I/O ; `si/so` = mémoire |
| **Un cœur à 100 %** | `mpstat -P ALL`, `top` (H) : mono-thread ; `perf top`, `strace -c -p` |
| **CPU `sy` élevé** | `strace -c -p`, `perf top`, interruptions réseau (`/proc/interrupts`), verrous |
| **`wa` élevé** | `iostat -xz`, `iotop`, `lsof +D`, NFS lent ? |
| **Mémoire qui diminue** | `ps --sort=-rss`, tendance, `smem`, `slabtop`, fuite ? |
| **Processus tué mystérieusement** | `journalctl -k \| grep -i oom` ; `dmesg` |
| **Disque plein** | `df -h`, `df -i`, `du -xh --max-depth=1`, `lsof +L1` |
| **« Too many open files »** | `/proc/PID/limits`, `ls /proc/PID/fd \| wc -l`, `lsof -p` |
| **Zombies** | `ps -eo pid,ppid,stat,cmd \| awk '$3~/Z/'` → corriger le **parent** (appel `wait()`) |
| **Latence réseau** | `mtr`, `ss -ti`, `tcpdump`, `time getent hosts` |
| **Lenteur uniquement sous charge** | `sar -q`, goulot de connexion (pool), contention verrou BD |
| **Après une mise à jour** | comparer (`journalctl -b -1`), `systemctl --failed`, `apt history`, revenir en arrière |

### Capturer l'historique : `sar`

Le paquet `sysstat` enregistre en continu (`/var/log/sysstat/`). Après un incident :
```bash
sar -u -s 02:00:00 -e 03:00:00                       # CPU entre 2h et 3h cette nuit
sar -r ; sar -b ; sar -n DEV -f /var/log/sysstat/sa07     # mémoire, I/O, réseau d'un jour précis
```

### Plantages : core dumps

```bash
ulimit -c unlimited ; cat /proc/sys/kernel/core_pattern
coredumpctl list ; coredumpctl info ; coredumpctl gdb        # systemd-coredump + gdb
gdb ./programme core -batch -ex 'bt full'                    # pile d'appels au moment du crash
dmesg | grep -i segfault
```

## 9. Optimiser : seulement après mesure

| Domaine | Leviers |
|---------|---------|
| CPU | gouverneur `performance` (`cpupower frequency-set -g performance`), affinité `taskset -c 0,1 commande`, `nice`, ajouter des cœurs, optimiser le code |
| Mémoire | `vm.swappiness`, hugepages (BD), limiter via cgroups, corriger les fuites |
| Disque | planificateur (`none`/`mq-deadline` pour SSD), `noatime`, `fstrim`, RAID/NVMe, séparer journaux et données, tuning du FS |
| Réseau | `net.core.somaxconn`, `net.ipv4.tcp_*` (fenêtres, `tcp_tw_reuse`), offloads NIC (`ethtool -K`), MTU jumbo (si tout le chemin le supporte) |
| Applications | pools de connexions, cache, index SQL, journaux asynchrones |

Outil d'optimisation système : `tuned` (RHEL : `tuned-adm profile throughput-performance`).

## 10. Rédiger un diagnostic

1. **Contexte** : symptôme, période, impact.
2. **Mesures** : commandes + sorties horodatées.
3. **Analyse** : ressource saturée (USE), cause racine.
4. **Action** : correctif appliqué, risque, retour arrière.
5. **Vérification** : métriques après correction.
6. **Prévention** : alerte, limite, test de charge, documentation.

## 11. Résumé

- Méthode : symptôme → hypothèse → mesure → un changement → vérification. **USE** par ressource.
- 60 secondes : `uptime`, `dmesg`, `vmstat`, `mpstat`, `pidstat`, `iostat -xz`, `free`, `sar -n`.
- Load average ≠ CPU ; `available` ≠ `free` ; `wa` élevé ⇒ disque ; `si/so` ⇒ mémoire.
- `/proc`, `lsof`, **`strace -c -p`**, `perf` pour entrer dans un processus.
- Pannes types : OOM, fuite de descripteurs, zombies, disque/inodes, conntrack.

## 12. Quiz

1. Pourquoi un `load average` de 8 n'est-il pas forcément problématique ? Quand l'est-il ?
2. `free` est à 200 Mo mais `available` à 5 Go : problème ?
3. `vmstat` : `r=12`, `b=0`, `id=0`, `wa=0` sur 4 cœurs. Diagnostic ?
4. Comment prouver qu'un processus fuit des descripteurs de fichiers ?
5. Que fait `strace -c -p PID` et quand l'utiliser ?
6. Où lit-on les traces du OOM killer ?
7. Un zombie ne répond pas à `kill -9` : pourquoi, et que faire ?
8. Un serveur « lent » avec CPU 5 % et load 9 : où chercher ?

<details><summary>Réponses</summary>

1. Sur une machine à 16 cœurs, 8 = 50 % de charge. Problématique si load > nombre de cœurs (saturation) ou si les tâches sont bloquées en I/O.
2. Non : le noyau utilise la RAM pour le cache ; `available` indique la mémoire réellement récupérable.
3. CPU saturé (CPU-bound) : 12 processus prêts pour 4 cœurs, pas d'attente I/O.
4. Observer `ls /proc/PID/fd | wc -l` (ou `lsof -p`) croître dans le temps vers `Max open files` dans `/proc/PID/limits`.
5. Résume le temps passé par appel système d'un processus en cours ; utile pour savoir s'il est bloqué en I/O, réseau ou verrous.
6. `journalctl -k | grep -i oom`, `dmesg -T | grep -i 'killed process'`.
7. Il est déjà mort (entrée de table non récoltée) ; il faut que le parent appelle `wait()` ou terminer/relancer le parent.
8. Tâches bloquées en I/O (état D) : disque, NFS, verrous ; `iostat -xz`, `ps -eo stat,cmd | grep '^D'`, `wa` dans `vmstat`.
</details>

➡️ **Labo** : [LAB.md](LAB.md) · **Démo** : `./lab demo 18` · **Suivant** : [19 — Serveurs web et reverse proxy](../19-serveurs-web-et-services/README.md)
