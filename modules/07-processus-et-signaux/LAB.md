# Labo 07 — Piloter des processus : signaux, priorité, arrêt propre

> **Durée** : 1 h 15 · **Difficulté** : ⭐⭐ · **Prérequis** : module 07

## Contexte

Deux services maison tournent mal. `worker.sh` est un démon bien élevé (il journalise les signaux, s'arrête proprement sur SIGTERM). `rebelle.sh` est un processus **récalcitrant** qui ignore SIGTERM. Vous devez les piloter comme un administrateur.

## Mise en place

```bash
./lab setup 07
cd ~/labs/07 && ls -l && cat worker.sh
```

## Tâches

Travaillez dans `~/labs/07`.

### Partie 1 — Le démon `worker.sh`

1. Lancez `worker.sh` **en arrière-plan avec `nohup`**, sortie standard et erreur dans `worker.out`. Écrivez son **PID** dans `pid.txt` (utilisez `$!`).
2. Envoyez-lui le signal **SIGUSR1** : il doit écrire `USR1 recu` dans `worker.log`.
3. Passez sa niceness à **10** avec `renice`, et écrivez la valeur lue avec `ps` dans `nice.txt` (un nombre seul).
4. Arrêtez-le **proprement** avec **SIGTERM**. Le fichier `worker.log` doit contenir la ligne `arret propre (nice=10)`.

### Partie 2 — Le processus récalcitrant `rebelle.sh`

5. Lancez `rebelle.sh` en arrière-plan.
6. Envoyez-lui **SIGTERM** : il l'ignore (et écrit `TERM ignore` dans `rebelle.log`). Constatez qu'il tourne toujours (`ps`, `pgrep`).
7. Éliminez-le avec le signal qui ne peut pas être ignoré. Écrivez son **numéro** dans `kill.txt` (un nombre seul).

### Partie 3 — Observation

8. Écrivez dans `observation.txt` : `PPID_SHELL=<PID du parent de votre shell>` (via `ps -o ppid= -p $$`) et `PID1=<nom de la commande du PID 1>` (via `ps -p 1 -o comm=`).

## Validation

```bash
./lab check 07
```

<details><summary>💡 Indices</summary>

- `nohup ./worker.sh > worker.out 2>&1 & echo $! > pid.txt`
- `kill -USR1 "$(cat pid.txt)"` · `renice -n 10 -p "$(cat pid.txt)"` · `ps -o ni= -p "$(cat pid.txt)"`
- `kill -TERM …` (ou simplement `kill …`). Attendez une seconde entre chaque action pour laisser le script réagir.
- `kill -9` = `SIGKILL`.
</details>

<details><summary>✅ Solution</summary>

```bash
cd ~/labs/07
nohup ./worker.sh > worker.out 2>&1 & echo $! > pid.txt
sleep 1; kill -USR1 "$(cat pid.txt)"
sleep 1; renice -n 10 -p "$(cat pid.txt)"
ps -o ni= -p "$(cat pid.txt)" | tr -d ' ' > nice.txt
kill -TERM "$(cat pid.txt)"; sleep 1

./rebelle.sh & REB=$!
sleep 1; kill -TERM $REB; sleep 1
ps -p $REB && echo "toujours là !"
kill -9 $REB; echo 9 > kill.txt

{ echo "PPID_SHELL=$(ps -o ppid= -p $$ | tr -d ' ')"; echo "PID1=$(ps -p 1 -o comm= | tr -d ' ')"; } > observation.txt
```
</details>

## Pour aller plus loin

- Suspendez `rebelle.sh` avec `kill -STOP` puis reprenez-le avec `kill -CONT` ; observez l'état `T` dans `ps`.
- Écrivez un script qui crée un **zombie** (parent qui `sleep` sans `wait`) et repérez-le avec `ps -eo pid,ppid,stat,cmd | awk '$3~/Z/'`.
- Ouvrez `tmux`, lancez `top`, détachez, rattachez la session.

## Nettoyage

```bash
./lab reset 07     # tue aussi les processus restants du labo
```
