#!/usr/bin/env bash
# Démo formateur — module 09 (≈ 30 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Un premier script, de zéro"
demo_run "cat > hello.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
nom=\${1:-monde}
echo \"Bonjour \$nom depuis \$(hostname), il est \$(date +%H:%M)\"
EOF
chmod +x hello.sh && ./hello.sh && ./hello.sh Alice"

demo_title "Guillemets : le piège de l'espace"
demo_run "f='mon fichier.txt'; touch \"\$f\"; ls \$f 2>&1 | head -2; echo '--'; ls \"\$f\""

demo_title "Expansion de paramètres"
demo_run "f=/data/rapport.tar.gz; echo \"\${f##*/} | \${f%.gz} | \${f%%.*} | \${#f} | \${f//\\//_} | \${UNSET:-par-defaut}\""
demo_run "m='linux'; echo \"\${m^^} \${m:0:3} \${m/nu/NU}\""

demo_title "Tests, boucles, case"
demo_run "for f in /etc/hostname /etc/nope /tmp; do if [[ -f \$f ]]; then echo \"\$f fichier\"; elif [[ -d \$f ]]; then echo \"\$f dossier\"; else echo \"\$f absent\"; fi; done"
demo_run "for i in {1..3}; do printf '%s ' \"\$((i*i))\"; done; echo"
demo_run "case 'stop' in start|up) echo démarre;; stop) echo arrête;; *) echo ?;; esac"

demo_title "Tableaux et tableaux associatifs"
demo_run "a=(pomme poire kiwi); echo \"\${#a[@]} fruits: \${a[*]} — dernier: \${a[-1]}\""
demo_run "declare -A p=([alice]=30 [bob]=25); for k in \"\${!p[@]}\"; do echo \"\$k=\${p[\$k]}\"; done | sort"

demo_title "Fonctions et codes retour"
demo_run "somme() { local t=0 n; for n in \"\$@\"; do t=\$((t+n)); done; echo \$t; }; echo \"somme=\$(somme 4 5 6)\""
demo_run "est_pair() { (( \$1 % 2 == 0 )); }; est_pair 10 && echo oui; est_pair 7 || echo non"

demo_title "Le mode strict en action"
demo_run "bash -c 'echo avant; false; echo APRES' ; echo ---; bash -c 'set -e; echo avant; false; echo APRES'"
demo_run "bash -c 'set -u; echo \$VARIABLE_ABSENTE' 2>&1 | head -1"
demo_run "bash -c 'false | true; echo \"sans pipefail rc=\$?\"'; bash -c 'set -o pipefail; false | true; echo \"avec pipefail rc=\$?\"'"

demo_title "trap : nettoyage garanti"
demo_run "bash -c 'tmp=\$(mktemp -d); trap \"echo nettoyage de \$tmp; rm -rf \$tmp\" EXIT; echo travail dans \$tmp; exit 3'; echo \"rc=\$?\""

demo_title "Déboguer : bash -x et shellcheck"
demo_run "printf '#!/usr/bin/env bash\\nx=3\\ny=\$((x*2))\\necho \$y\\n' > dbg.sh; bash -x dbg.sh"
if command -v shellcheck >/dev/null; then
  demo_run "printf '#!/usr/bin/env bash\\nrm -rf \$DIR/*\\nfor f in \$(ls); do echo \$f; done\\n' > mauvais.sh; shellcheck mauvais.sh | head -12"
else
  demo_say "(shellcheck non installé : apt install shellcheck)"
fi
demo_end
