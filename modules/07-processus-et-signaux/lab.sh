#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=07

# Motif ancré : « bash ./worker.sh » — ne correspond pas à un shell dont la ligne de commande mentionne juste le nom
PROC_RE='^(/[a-z/]*/)?bash (\./|/.*/)?(worker|rebelle)\.sh$'
lab_cleanup() { pkill -9 -f "$PROC_RE" 2>/dev/null; return 0; }

lab_setup() {
  cd "$LAB_DIR" || return 1
  cat > worker.sh <<'EOF'
#!/usr/bin/env bash
# Démon d'exemple : journalise les signaux, s'arrête proprement sur SIGTERM.
LOG="$(dirname "$0")/worker.log"
echo "demarre pid=$$" > "$LOG"
trap 'echo "USR1 recu" >> "$LOG"' USR1
trap 'echo "arret propre (nice=$(ps -o ni= -p $$ | tr -d " "))" >> "$LOG"; exit 0' TERM
while true; do sleep 0.2; done
EOF
  cat > rebelle.sh <<'EOF'
#!/usr/bin/env bash
# Processus récalcitrant : ignore SIGTERM.
LOG="$(dirname "$0")/rebelle.log"
echo "demarre pid=$$" > "$LOG"
trap 'echo "TERM ignore" >> "$LOG"' TERM
while true; do sleep 0.2; done
EOF
  chmod +x worker.sh rebelle.sh
  rm -f worker.log rebelle.log pid.txt nice.txt kill.txt observation.txt worker.out
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local pid; pid=$(tr -d ' \n' < pid.txt 2>/dev/null)
  assert "pid.txt contient un PID numérique" test -n "$pid" -a "$pid" -gt 0 2>/dev/null
  assert "worker.out existe (nohup/redirection)" test -f worker.out
  assert_grep "worker.log : démarrage" '^demarre pid=' worker.log
  assert_grep "worker.log : SIGUSR1 reçu" '^USR1 recu$' worker.log
  assert_grep "worker.log : arrêt propre avec nice=10 (SIGTERM après renice)" '^arret propre \(nice=10\)$' worker.log
  assert_eq "nice.txt = 10" "10" "$(tr -d ' \n' < nice.txt 2>/dev/null)"
  absent() { ! pgrep -f "^(/[a-z/]*/)?bash (\./|/.*/)?$1\.sh$" >/dev/null; }
  assert "worker.sh n'est plus en cours d'exécution" absent worker

  assert_grep "rebelle.log : SIGTERM ignoré" '^TERM ignore$' rebelle.log
  assert "rebelle.sh a bien été éliminé" absent rebelle
  assert_eq "kill.txt = 9 (SIGKILL)" "9" "$(tr -d ' \n' < kill.txt 2>/dev/null)"
  assert_eq "PPID_SHELL" "PPID" "$(grep -q '^PPID_SHELL=[0-9]\+$' observation.txt 2>/dev/null && echo PPID)"
  assert_eq "PID1" "$(ps -p 1 -o comm= | tr -d ' ')" "$(grep '^PID1=' observation.txt 2>/dev/null | cut -d= -f2)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  nohup ./worker.sh > worker.out 2>&1 &
  echo $! > pid.txt
  sleep 1; kill -USR1 "$(cat pid.txt)"
  sleep 1; renice -n 10 -p "$(cat pid.txt)" >/dev/null
  ps -o ni= -p "$(cat pid.txt)" | tr -d ' ' > nice.txt
  kill -TERM "$(cat pid.txt)"; sleep 1
  ./rebelle.sh &
  local reb=$!
  sleep 1; kill -TERM "$reb"; sleep 1
  kill -9 "$reb"; echo 9 > kill.txt
  wait "$reb" 2>/dev/null
  { echo "PPID_SHELL=$(ps -o ppid= -p $$ | tr -d ' ')"; echo "PID1=$(ps -p 1 -o comm= | tr -d ' ')"; } > observation.txt
}

lab_main "$@"
