#!/usr/bin/env bash
# Démo formateur — module 03 (≈ 20 min)
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/demo-lib.sh"

demo_title "Créer en masse"
demo_run "mkdir -p projet/{src,docs,tests} && echo 'int main(){}' | tee projet/src/{main,util}.c >/dev/null && touch projet/docs/readme.md"
demo_run "ls -R projet"

demo_title "Copier : cp -r vs cp -a"
demo_run "touch -d '2020-01-01' projet/docs/ancien.md"
demo_run "cp -r projet copie_r && cp -a projet copie_a"
demo_run "ls -l --time-style=long-iso projet/docs/ancien.md copie_r/docs/ancien.md copie_a/docs/ancien.md | awk '{print \$6, \$8}'"
demo_say "Seul -a préserve la date d'origine."

demo_title "Guillemets : le piège des espaces"
demo_run "nom='Mes Documents'; mkdir \$nom; ls -d Mes Documents"
demo_run "rmdir Mes Documents; mkdir \"\$nom\"; ls -d \"\$nom\""

demo_title "Liens durs et symboliques"
demo_run "echo 'contenu' > source.txt && ln source.txt dur.txt && ln -s source.txt sym.txt"
demo_run "ls -li source.txt dur.txt sym.txt"
demo_run "rm source.txt"
demo_run "cat dur.txt"
demo_run "cat sym.txt 2>&1"
demo_say "Le lien dur survit, le lien symbolique est cassé."
demo_run "find . -maxdepth 1 -xtype l"

demo_title "find : chercher puis agir"
demo_run "touch -d '40 days ago' vieux.tmp; touch recent.tmp; echo data > gros.dat; head -c 200000 /dev/zero > enorme.bin"
demo_run "find . -maxdepth 1 -name '*.tmp' -mtime +30"
demo_run "find . -maxdepth 1 -type f -size +100k"
demo_run "find . -maxdepth 1 -name '*.tmp' -mtime +30 -delete && ls *.tmp"
demo_run "find projet -type f -name '*.c' -exec wc -c {} +"

demo_title "Occupation disque"
demo_run "du -sh projet copie_a"
demo_run "du -ah . | sort -rh | head -3"
demo_run "df -h . | tail -1"
demo_run "df -i . | tail -1"

demo_title "Sécurité : rm avec variable vide"
demo_show "DIR=''; rm -rf \$DIR/*     # ⚠️ devient rm -rf /* !!!"
demo_show "rm -rf -- \"\${DIR:?variable vide}\"/*   # ✔ le shell s'arrête avec une erreur"
demo_run "DIR=''; (: \"\${DIR:?variable vide}\") 2>&1 | head -1"
demo_end
