# Labo 18 — Enquête : cinq processus coupables et trois échantillons de mesures

> **Durée** : 4 h · **Difficulté** : ⭐⭐⭐⭐ · **Prérequis** : module 18 · outils : `ps`, `top`, `lsof`, `strace`, `vmstat`

## Contexte

« Le serveur est lent depuis ce matin. » Le labo lance cinq programmes `lab18-*` qui se comportent mal. Vous devez les **identifier avec les outils standard**, prendre des mesures, puis appliquer les bonnes actions. Vous interpréterez aussi trois échantillons `vmstat` provenant d'autres machines.

## Mise en place

```bash
./lab setup 18
cd ~/labs/18 && ls && ps aux | grep '[l]ab18'
```

> ⚠️ Les processus consomment réellement CPU, mémoire et disque pendant le labo. `./lab reset 18` les arrête tous.

## Tâches (dans `~/labs/18`)

### A. Identification
1. `cpu.txt` : le **PID** du processus `lab18-*` qui consomme le plus de **CPU**.
2. `mem.txt` : le **PID** de celui qui a le plus gros **RSS** (mémoire résidente).
3. `fd.txt` : le **PID** de celui qui a le plus de **descripteurs de fichiers ouverts** (`/proc/PID/fd`, `lsof`).
4. `zombies.txt` :
   ```
   PARENT_ZOMBIES=<PID du processus parent des zombies>
   NB_ZOMBIES=<nombre de zombies dont le parent est ce processus>
   ```
5. `io.txt` : le **PID** de celui qui effectue de lourdes **écritures disque synchrones** (indices : `iotop`/`pidstat -d`, `/proc/PID/io`, `strace`).

### B. Observation du coupable d'I/O
6. Tracez pendant quelques secondes le processus d'I/O avec **`strace -c -p PID`** (quittez avec `Ctrl+C` ou `timeout 5`) et enregistrez la synthèse dans `strace.txt` (elle doit mentionner `fsync` ou `write`). Si `ptrace` est interdit dans votre environnement, écrivez `SKIP` dans le fichier.

### C. Actions
7. Passez le processus qui consomme le CPU à la priorité la plus basse (**nice 19**).
8. **Terminez proprement** (SIGTERM) les processus coupables de fuite mémoire et de fuite de descripteurs.
9. Laissez en vie le processus d'I/O et le parent des zombies (ils servent de témoins).

### D. Lire des mesures (`echantillon1.txt` à `echantillon3.txt` fournis)
10. Dans `goulot.txt`, indiquez pour chaque échantillon le goulot d'étranglement principal parmi `cpu`, `io`, `memoire` :
    ```
    ECH1=...
    ECH2=...
    ECH3=...
    ```

## Validation

```bash
./lab check 18
```

<details><summary>💡 Indices</summary>

- `ps -eo pid,pcpu,rss,cmd --sort=-pcpu | grep '[l]ab18' ` · `--sort=-rss`
- `for p in $(pgrep -f lab18); do echo "$p $(ls /proc/$p/fd | wc -l)"; done`
- `ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^Z/'`
- `cat /proc/PID/io` (comparez `write_bytes` deux fois à 5 s d'intervalle) ou `pidstat -d 1 3`
- `sudo timeout 5 strace -c -f -p PID 2> strace.txt`
- `sudo renice -n 19 -p PID` · `kill PID`
- Échantillons : regardez `r`, `b`, `si/so`, `us`, `wa`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/18
PIDS=$(pgrep -f 'lab18-')                # PID des python lab18-*
CPU=$(ps -o pid=,pcpu=,cmd= -p $(echo $PIDS | tr ' ' ',') | sort -k2 -rn | head -1 | awk '{print $1}')
MEM=$(ps -o pid=,rss=,cmd= -p $(echo $PIDS | tr ' ' ',') | sort -k2 -rn | head -1 | awk '{print $1}')
FD=$(for p in $PIDS; do echo "$(ls /proc/$p/fd | wc -l) $p"; done | sort -rn | head -1 | cut -d' ' -f2)
echo $CPU > cpu.txt; echo $MEM > mem.txt; echo $FD > fd.txt
ZP=$(ps -eo ppid=,stat= | awk '$2 ~ /^Z/ {print $1}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
{ echo "PARENT_ZOMBIES=$ZP"; echo "NB_ZOMBIES=$(ps -eo ppid=,stat= | awk -v z=$ZP '$1==z && $2 ~ /^Z/' | wc -l)"; } > zombies.txt
IO=$(pgrep -f lab18-io); echo $IO > io.txt
sudo timeout 5 strace -c -f -p $IO 2> strace.txt
sudo renice -n 19 -p $CPU
kill $MEM $FD
printf 'ECH1=cpu\nECH2=io\nECH3=memoire\n' > goulot.txt
```
</details>

## Pour aller plus loin

- Mesurez avec `pidstat -r -p PID 2` la croissance du RSS de `lab18-mem` avant de le tuer.
- Cherchez avec `perf top -p PID` (si disponible) la fonction chaude du coupable CPU.
- Écrivez un script `diagnostic.sh` qui exécute la checklist des « 60 secondes » et sauve les sorties horodatées.
- Limitez un processus avec `systemd-run --scope -p MemoryMax=100M -p CPUQuota=20% python3 …`.

## Nettoyage

```bash
./lab reset 18     # arrête tous les processus lab18-*
```
