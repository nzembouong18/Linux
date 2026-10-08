#!/usr/bin/env bash
# Démo formateur — module 04 (≈ 15 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Un journal d'exemple"
demo_run "for i in \$(seq 1 30); do echo \"2024-03-01 10:00:\$(printf %02d \$i) INFO requete \$i\"; done > app.log"
demo_run "wc -l app.log"

demo_title "head, tail, sed -n"
demo_run "head -n 3 app.log"
demo_run "tail -n 2 app.log"
demo_run "sed -n '10,12p' app.log"
demo_run "nl app.log | sed -n '5,6p'"

demo_title "tail -f en direct"
demo_say "Un producteur écrit dans le journal pendant que tail le suit."
demo_run "(sleep 0.5; echo 'ERROR: disque plein' >> app.log) & timeout 2 tail -n 1 -f app.log; wait"

demo_title "Caractères invisibles"
demo_run "printf 'ligne1\\tTAB\\r\\nligne2\\n' > win.txt; cat -A win.txt"
demo_say "^M = retour chariot Windows → 'bad interpreter: /bin/bash^M' dans les scripts."
demo_run "sed -i 's/\\r\$//' win.txt; cat -A win.txt"

demo_title "Éditer sans interface : sed -i et vim -es"
demo_run "printf '[server]\\nport=80\\ndebug=true\\n' > config.ini"
demo_run "sed -i.bak 's/^port=.*/port=8080/' config.ini && diff config.ini.bak config.ini"
demo_run "vim -es -c '%s/debug=true/debug=false/' -c 'wq' config.ini && cat config.ini"
demo_say "En vrai : lancez vimtutor, i / Esc / :wq / :q! / dd / yy / p / u."

demo_title "Inspecter un binaire"
demo_run "file /bin/ls | cut -c1-90"
demo_run "strings /bin/ls | grep -m2 -i 'usage'"
demo_run "xxd /bin/ls | head -2"
demo_end
