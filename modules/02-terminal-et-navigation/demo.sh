#!/usr/bin/env bash
# Démo formateur — module 02 (≈ 15 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Le shell et ses commandes"
demo_run "echo \"Shell : \$0 — PATH commence par : \$(echo \$PATH | cut -d: -f1-3)\""
demo_run "type cd ls grep"
demo_say "cd est un builtin (interne au shell), ls un programme, parfois aliasé."

demo_title "L'arborescence FHS en direct"
demo_run "ls /"
demo_run "ls /etc | head -8"
demo_run "ls -ld /tmp /root /home"
demo_say "Les droits de /tmp se terminent par t : sticky bit — nous y reviendrons au module 06."

demo_title "Chemins absolus et relatifs"
demo_run "mkdir -p projet/src/app projet/docs && cd projet/src/app"
demo_run "pwd"
demo_run "cd ../../docs && pwd"
demo_run "cd - && pwd"
demo_say "Chemin relatif de src/app vers docs :"
demo_run "realpath --relative-to=. ../../docs"

demo_title "ls -l décortiqué"
demo_run "cd \"$DEMO_DIR\" && touch fichier.txt && mkdir dossier && ln -s fichier.txt lien"
demo_run "ls -lah"
demo_run "ls -li"
demo_run "file fichier.txt dossier lien /bin/ls"
demo_run "stat -c '%n  inode=%i  taille=%s  droits=%A' fichier.txt"

demo_title "Globbing"
demo_run "touch a1.log a2.log b1.log notes.txt"
demo_run "ls *.log; ls a?.log; ls [ab]1.log; echo f{1..3}.dat"
demo_end
