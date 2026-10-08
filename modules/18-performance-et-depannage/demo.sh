#!/usr/bin/env bash
# Démo formateur — module 18 (≈ 45 min). Génère de vrais problèmes (brefs) puis les diagnostique.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill -9 "$p" 2>/dev/null; done; cd /; rm -rf "$DEMO_DIR"; }
trap cleanup EXIT

demo_title "Les 60 secondes : première vue"
demo_run "uptime; nproc"
demo_run "vmstat 1 3"
demo_run "free -m"
demo_run "mpstat -P ALL 1 1 2>/dev/null | tail -n +4 | head -6"
demo_run "iostat -xz 1 2 2>/dev/null | tail -n 8"

demo_title "Cas 1 — un processus qui consomme tout un cœur"
python3 -c 'while True: pass' & PIDS+=($!)
sleep 1
demo_run "ps -eo pid,pcpu,stat,cmd --sort=-pcpu | head -3"
demo_run "top -b -n1 -o %CPU | sed -n '7,9p' | cut -c1-80"
demo_run "ls /proc/${PIDS[0]}/fd | wc -l; tr '\\0' ' ' < /proc/${PIDS[0]}/cmdline; echo"
demo_run "renice -n 19 -p ${PIDS[0]} && ps -o pid,ni,pcpu,cmd -p ${PIDS[0]}; kill ${PIDS[0]}"

demo_title "Cas 2 — fuite de descripteurs de fichiers"
python3 -c 'import time; f=[open("/dev/null") for _ in range(400)]; time.sleep(60)' & PIDS+=($!)
sleep 0.7
demo_run "ls /proc/${PIDS[1]}/fd | wc -l"
demo_run "grep 'Max open files' /proc/${PIDS[1]}/limits"
demo_run "lsof -p ${PIDS[1]} 2>/dev/null | awk 'NR>1{print \$4,\$5,\$9}' | sort | uniq -c | sort -rn | head -3"
demo_run "kill ${PIDS[1]}"

demo_title "Cas 3 — des zombies"
python3 -c 'import os,time
for _ in range(3):
    if os.fork()==0: os._exit(0)
time.sleep(60)' & PIDS+=($!)
sleep 0.7
demo_run "ps -eo pid,ppid,stat,cmd | awk 'NR==1 || \$3 ~ /^Z/' | cut -c1-70"
demo_say "On ne tue pas un zombie : on corrige son parent (PPID = ${PIDS[2]})."
demo_run "kill ${PIDS[2]}; sleep 0.5; ps -eo stat | grep -c '^Z' || true"

demo_title "Cas 4 — qui écrit sur le disque ? strace -c"
python3 -c '
import os,time
f=open("io.dat","wb")
while True:
    f.seek(0); f.write(b"x"*65536); f.flush(); os.fsync(f.fileno()); time.sleep(0.02)' & PIDS+=($!)
sleep 1
demo_run "cat /proc/${PIDS[3]}/io | grep -E 'write_bytes|syscw'"
demo_run "timeout 3 strace -c -f -p ${PIDS[3]} -o st.txt 2>/dev/null; head -6 st.txt || echo '(ptrace indisponible)'"
demo_run "kill ${PIDS[3]}"

demo_title "Cas 5 — OOM : où lire les traces ?"
demo_run "dmesg -T 2>/dev/null | grep -i -E 'out of memory|oom' | tail -2; echo '(rien = pas d OOM récent)'"
demo_show "journalctl -k | grep -i 'killed process'   |   cat /proc/PID/oom_score   |   echo -500 | sudo tee /proc/PID/oom_score_adj"

demo_title "Historique avec sar (sysstat)"
demo_run "ls /var/log/sysstat 2>/dev/null | head -3; sar -u 1 2 2>/dev/null | tail -3"
demo_end
