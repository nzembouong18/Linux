#!/usr/bin/env bash
# Démo formateur — module 07 (≈ 20 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Qui suis-je dans l'arbre des processus ?"
demo_run "echo \"PID du shell: \$\$  — parent: \$(ps -o ppid= -p \$\$)\""
demo_run "ps -o pid,ppid,stat,ni,etime,cmd -p \$\$"
demo_run "pstree -ps \$\$ 2>/dev/null || ps -ef --forest | head -5"

demo_title "ps : trier par consommation"
demo_run "ps -eo pid,user,stat,%cpu,%mem,comm --sort=-%mem | head -5"
demo_run "ps -eo stat --no-headers | cut -c1 | sort | uniq -c"

demo_title "/proc : la source de vérité"
demo_run "tr '\\0' ' ' < /proc/\$\$/cmdline; echo"
demo_run "ls -l /proc/\$\$/cwd /proc/\$\$/exe | awk '{print \$9, \$10, \$11}'"
demo_run "ls /proc/\$\$/fd | head -3"

demo_title "Arrière-plan et jobs"
demo_run "sleep 30 & echo \"PID du dernier job: \$!\""
demo_run "jobs -l"
demo_run "kill %1; sleep 0.3; jobs"

demo_title "Signaux : TERM poli vs KILL brutal"
demo_run "cat > svc.sh <<'EOF'
#!/usr/bin/env bash
trap 'echo \"  [svc] SIGTERM reçu, nettoyage...\"; exit 0' TERM
trap 'echo \"  [svc] SIGHUP : je recharge ma config\"' HUP
while true; do sleep 0.2; done
EOF
chmod +x svc.sh; ./svc.sh & SVC=\$!; sleep 0.5; echo \"svc PID=\$SVC\""
demo_run "kill -HUP \$SVC; sleep 0.5"
demo_run "kill -STOP \$SVC; ps -o pid,stat,cmd -p \$SVC; kill -CONT \$SVC"
demo_run "kill -TERM \$SVC; sleep 0.5; wait \$SVC; echo \"code retour: \$?\""
demo_say "Avec SIGKILL le script n'aurait pas pu afficher son message : le noyau le tue directement."
demo_run "sleep 100 & P=\$!; kill -9 \$P; wait \$P 2>/dev/null; echo \"code retour: \$? (128+9)\""

demo_title "nice / renice"
demo_run "nice -n 15 sleep 20 & ps -o pid,ni,cmd -p \$!"
demo_run "renice -n 19 -p \$! && ps -o pid,ni,cmd -p \$!; kill \$!"

demo_title "Un zombie en direct"
demo_run "bash -c 'sleep 0.3 & exec sleep 3' & sleep 1; ps -eo pid,ppid,stat,comm | awk '\$3 ~ /Z/ || NR==1' | head -3; wait"
demo_say "Le zombie disparaît quand son parent se termine (adopté puis récolté par PID 1)."
demo_end
