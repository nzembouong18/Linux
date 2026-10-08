#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=18
LAB_REQUIRES=(cmd:python3 cmd:ps)

# Motif ANCRÉ sur « python3 … » : un shell dont la ligne de commande mentionne juste le nom ne correspond pas
proc_re() { echo "^python3 .*lab18-$1\\.py\$"; }
lab_pid() { # lab_pid <cpu|mem|fd|io|zomb> → PID du processus principal
  pgrep -f "$(proc_re "$1")" | head -1
}

lab_cleanup() {
  local k p
  for k in cpu mem fd io zomb; do
    for p in $(pgrep -f "$(proc_re "$k")" 2>/dev/null); do kill -9 "$p" 2>/dev/null; done
  done
  return 0
}

lab_setup() {
  cd "$LAB_DIR" || return 1
  lab_cleanup
  rm -rf bin ./*.txt io.dat
  mkdir -p bin
  cat > bin/lab18-cpu.py <<'EOF'
# Consomme 100 % d'un cœur
while True:
    pass
EOF
  cat > bin/lab18-mem.py <<'EOF'
# Fuite mémoire : alloue ~150 Mo et les touche, puis dort
import time
buf = bytearray(150 * 1024 * 1024)
for i in range(0, len(buf), 4096):
    buf[i] = 1
while True:
    time.sleep(60)
EOF
  cat > bin/lab18-fd.py <<'EOF'
# Fuite de descripteurs : ouvre ~700 fichiers sans jamais les fermer
import time
fds = [open('/dev/null') for _ in range(700)]
while True:
    time.sleep(60)
EOF
  cat > bin/lab18-io.py <<'EOF'
# Écritures synchrones répétées (fsync) : sollicite le disque, très peu de CPU
import os, sys, time
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'io.dat')
data = b'x' * (256 * 1024)
while True:
    with open(path, 'wb') as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    time.sleep(0.02)
EOF
  cat > bin/lab18-zomb.py <<'EOF'
# Parent négligent : crée 3 enfants qui meurent aussitôt et ne les récolte jamais (wait)
import os, time
for _ in range(3):
    if os.fork() == 0:
        os._exit(0)
while True:
    time.sleep(60)
EOF
  local k
  for k in cpu mem fd io zomb; do
    nohup python3 "$LAB_DIR/bin/lab18-$k.py" >/dev/null 2>&1 </dev/null &
  done
  cat > echantillon1.txt <<'EOF'
# vmstat 1 5   (machine A : serveur d'application, 4 cœurs)
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 9  0      0 812344  80212 912344    0    0     2     5 1204 3011 94  4  2  0  0
10  0      0 811900  80212 912500    0    0     0     0 1311 3122 95  4  1  0  0
 9  0      0 811820  80212 912500    0    0     0    12 1289 3090 96  3  1  0  0
11  0      0 811700  80216 912520    0    0     0     0 1302 3201 95  4  1  0  0
 9  0      0 811650  80216 912520    0    0     0     0 1295 3170 96  3  1  0  0
EOF
  cat > echantillon2.txt <<'EOF'
# vmstat 1 5   (machine B : serveur de base de données, 4 cœurs)
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 1 14      0 220344  40212 1912344    0    0 18200 42011  2204 3511  4  3  9 84  0
 0 15      0 219900  40212 1912500    0    0 17110 45100  2111 3322  3  4  8 85  0
 2 13      0 219820  40212 1912500    0    0 19020 40012  2189 3490  5  3  7 85  0
 1 15      0 219700  40216 1912520    0    0 18800 43500  2250 3601  4  4  8 84  0
 0 14      0 219650  40216 1912520    0    0 17900 44100  2230 3550  4  3  9 84  0
EOF
  cat > echantillon3.txt <<'EOF'
# vmstat 1 5   (machine C : serveur applicatif Java, 4 cœurs, 8 Go)
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 3  4 6291456  41200   1200  88000 5400 8800  5600  9100 3204 6511 12 14 20 54  0
 2  5 6392832  39800   1100  87500 6100 9300  6200  9600 3311 6722 10 15 18 57  0
 4  3 6489000  38200   1100  86900 5800 9900  5900 10100 3290 6690 11 16 17 56  0
 3  6 6590100  37100   1000  86000 6600 9600  6700  9800 3350 6801  9 17 16 58  0
 2  5 6680300  36800   1000  85500 6900 9100  7000  9300 3340 6755 10 16 15 59  0
EOF
  sleep 2
}

lab_check() {
  cd "$LAB_DIR" || return 1
  # PID de référence : mémorisés au premier passage (les processus peuvent ensuite être tués, étape C)
  if [[ ! -f .pids ]]; then
    printf 'cpu=%s\nmem=%s\nfd=%s\nio=%s\nzomb=%s\n' "$(lab_pid cpu)" "$(lab_pid mem)" "$(lab_pid fd)" "$(lab_pid io)" "$(lab_pid zomb)" > .pids
  fi
  local ref; ref() { grep -E "^$1=" .pids 2>/dev/null | cut -d= -f2; }
  local g; g() { [[ -f "$1" ]] && tr -d ' \n' < "$1"; }
  assert_eq "A1 cpu.txt = processus gourmand en CPU" "$(ref cpu)" "$(g cpu.txt)"
  assert_eq "A2 mem.txt = plus gros RSS" "$(ref mem)" "$(g mem.txt)"
  assert_eq "A3 fd.txt = fuite de descripteurs" "$(ref fd)" "$(g fd.txt)"
  assert_eq "A4 PARENT_ZOMBIES" "$(ref zomb)" "$(grep -E '^PARENT_ZOMBIES=' zombies.txt 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  assert_eq "A4 NB_ZOMBIES" 3 "$(grep -E '^NB_ZOMBIES=' zombies.txt 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  assert_eq "A5 io.txt = écritures synchrones" "$(ref io)" "$(g io.txt)"
  if grep -q '^SKIP' strace.txt 2>/dev/null; then skip "B6 strace"; else assert_grep "B6 strace.txt : synthèse mentionnant fsync/write" 'fsync|write' strace.txt; fi
  # « vivant » = existe et n'est pas un zombie (un processus tué non récolté par son parent reste Z)
  alive() { local st; st=$(ps -o stat= -p "$1" 2>/dev/null | tr -d ' '); [[ -n $st && $st != Z* ]]; }
  local ni; ni=$(ps -o ni= -p "$(ref cpu)" 2>/dev/null | tr -d ' ')
  assert_eq "C7 nice du processus CPU = 19" 19 "$ni"
  assert "C8 lab18-mem terminé" bash -c "$(declare -f alive); ! alive $(ref mem)"
  assert "C8 lab18-fd terminé" bash -c "$(declare -f alive); ! alive $(ref fd)"
  assert "C9 lab18-io toujours actif" alive "$(ref io)"
  assert "C9 le parent des zombies est toujours actif" alive "$(ref zomb)"
  assert_eq "D10 ECH1 (r élevé, us 95 %)" cpu "$(grep -E '^ECH1=' goulot.txt 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  assert_eq "D10 ECH2 (b élevé, wa 85 %)" io "$(grep -E '^ECH2=' goulot.txt 2>/dev/null | cut -d= -f2 | tr -d ' ')"
  assert_eq "D10 ECH3 (swap si/so massif)" memoire "$(grep -E '^ECH3=' goulot.txt 2>/dev/null | cut -d= -f2 | tr -d ' ')"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  local pids p
  pids=$(pgrep -f '^python3 .*lab18-(cpu|mem|fd|io|zomb)\.py$' | tr '\n' ' ')
  # sauvegarde des PID de référence pour le correcteur
  printf 'cpu=%s\nmem=%s\nfd=%s\nio=%s\nzomb=%s\n' "$(lab_pid cpu)" "$(lab_pid mem)" "$(lab_pid fd)" "$(lab_pid io)" "$(lab_pid zomb)" > .pids
  local cpu mem fd io zp
  # CPU : échantillon sur 2 s (pcpu cumulé peu fiable au démarrage)
  cpu=$(top -b -n2 -d1 -p "$(echo "$pids" | tr -s ' ' ',' | sed 's/,$//')" 2>/dev/null | awk '/^ *[0-9]+ /{c[$1]=$9} END{m=-1; for(k in c) if(c[k]+0>m){m=c[k]+0; b=k}; print b}')
  mem=$(for p in $pids; do echo "$(awk '/VmRSS/{print $2}' /proc/"$p"/status) $p"; done | sort -rn | head -1 | cut -d' ' -f2)
  fd=$(for p in $pids; do echo "$(ls /proc/"$p"/fd 2>/dev/null | wc -l) $p"; done | sort -rn | head -1 | cut -d' ' -f2)
  io=$(lab_pid io)
  zp=$(ps -eo ppid=,stat= | awk '$2 ~ /^Z/ {print $1}' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  echo "$cpu" > cpu.txt; echo "$mem" > mem.txt; echo "$fd" > fd.txt; echo "$io" > io.txt
  { echo "PARENT_ZOMBIES=$zp"; echo "NB_ZOMBIES=$(ps -eo ppid=,stat= | awk -v z="$zp" '$1==z && $2 ~ /^Z/' | wc -l)"; } > zombies.txt
  if as_root timeout 4 strace -c -f -p "$io" -o strace.txt >/dev/null 2>&1 && [[ -s strace.txt ]]; then :; else echo SKIP > strace.txt; fi
  as_root renice -n 19 -p "$cpu" >/dev/null
  kill "$mem" "$fd" 2>/dev/null
  sleep 0.5
  printf 'ECH1=cpu\nECH2=io\nECH3=memoire\n' > goulot.txt
}

lab_main "$@"
