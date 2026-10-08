#!/usr/bin/env bash
# Démo formateur — module 05 (≈ 25 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Trois flux : stdin, stdout, stderr"
demo_run "ls /etc/hostname /inexistant"
demo_run "ls /etc/hostname /inexistant > out.txt 2> err.txt; echo '--out:'; cat out.txt; echo '--err:'; cat err.txt"
demo_run "ls /etc/hostname /inexistant > tout.txt 2>&1; cat tout.txt"
demo_say "Le piège de l'ordre : 2>&1 AVANT > ne redirige pas l'erreur vers le fichier."
demo_run "ls /etc/hostname /inexistant 2>&1 > piege.txt | sed 's/^/[écran] /'"

demo_title "Écraser vs ajouter, et le piège de sort f > f"
demo_run "printf 'c\\na\\nb\\n' > data.txt; echo d >> data.txt; cat data.txt"
demo_run "sort data.txt > data.txt; wc -c data.txt"
demo_say "Le fichier est vidé AVANT que sort ne le lise. La bonne façon :"
demo_run "printf 'c\\na\\nb\\n' > data.txt; sort -o data.txt data.txt; cat data.txt"

demo_title "Here-document"
demo_run "cat > conf.ini << EOF
[user]
name = \$(whoami)
EOF
cat conf.ini"

demo_title "Construire un pipeline pas à pas"
demo_run "for i in \$(seq 1 60); do echo \"10.0.0.\$(( (i*i) % 5 + 1 )) GET /page\$((i % 3)) \$(( (i%4==0) ? 404 : 200 ))\"; done > access.log; head -3 access.log"
demo_run "awk '{print \$1}' access.log | head -3"
demo_run "awk '{print \$1}' access.log | sort | uniq -c"
demo_run "awk '{print \$1}' access.log | sort | uniq -c | sort -rn | head -3"
demo_say "Les codes HTTP :"
demo_run "awk '{print \$4}' access.log | sort | uniq -c | sort -rn"

demo_title "grep dans tous ses états"
demo_run "grep -c 404 access.log"
demo_run "grep -n -m2 'page1' access.log"
demo_run "grep -E -o '10\\.0\\.0\\.[0-9]' access.log | sort -u"
demo_run "grep -v 200 access.log | head -2"

demo_title "tee, xargs, substitution de processus"
demo_run "echo 'important' | tee copie.txt | tr a-z A-Z"
demo_run "printf 'un\\ndeux\\ntrois\\n' | xargs -I{} echo 'ligne: {}'"
demo_run "diff <(printf 'a\\nb\\nc\\n') <(printf 'a\\nB\\nc\\n')"
demo_run "echo \"Il y a \$(ls | wc -l) fichiers dans \$(basename \$PWD | sed 's/[0-9a-zA-Z.]*//g')ce dossier\""
demo_end
