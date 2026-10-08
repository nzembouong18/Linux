#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=05

lab_setup() {
  cd "$LAB_DIR" || return 1
  local ips=(10.0.0.1 10.0.0.1 10.0.0.1 10.0.0.1 10.0.0.1 10.0.0.1 10.0.0.1 10.0.0.2 10.0.0.2 10.0.0.2 10.0.0.2 10.0.0.2 10.0.0.3 10.0.0.3 10.0.0.3 10.0.0.3 10.0.0.4 10.0.0.4 10.0.0.5 10.0.0.6)
  local urls=(/index.html /produits /contact /api/v1/items /login /panier /admin)
  local st=(200 200 200 200 200 200 404 404 500 301)
  local i
  : > access.log
  for i in $(seq 1 200); do
    printf '%s - - [01/Mar/2024:10:%02d:%02d +0000] "GET %s HTTP/1.1" %s %d\n' \
      "${ips[$(((i * 7) % 20))]}" $((i / 60)) $((i % 60)) "${urls[$(((i * 5 + i / 7) % 7))]}" "${st[$(((i * 3) % 10))]}" $((200 + (i * 37) % 5000)) >> access.log
  done
}

lab_check() {
  cd "$LAB_DIR" || return 1
  local norm='s/^ *//; s/  */ /g'
  assert "sortie.txt contient le listing de /etc" bash -c "grep -q '^passwd$' sortie.txt && ! grep -qi 'inexistant' sortie.txt"
  assert "erreurs.txt contient uniquement l'erreur" bash -c "grep -qi 'dossier-inexistant' erreurs.txt && ! grep -q '^passwd$' erreurs.txt"
  assert "tout.txt contient les deux flux" bash -c "grep -q '^passwd$' tout.txt && grep -qi 'dossier-inexistant' tout.txt"
  assert "bienvenue.txt (here-doc, whoami développé)" cmp -s bienvenue.txt <(printf 'Bonjour %s\nFin du message\n' "$(whoami)")
  assert "erreurs_404.txt" cmp -s erreurs_404.txt <(awk '$9 == 404' access.log)
  assert_eq "nb_404.txt" "$(awk '$9 == 404' access.log | wc -l)" "$(tr -d ' \n' < nb_404.txt 2>/dev/null)"
  assert "top_ips.txt (3 premières IP)" cmp -s <(sed "$norm" top_ips.txt 2>/dev/null) <(awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -3 | sed "$norm")
  assert "urls.txt (triées, uniques)" cmp -s urls.txt <(awk '{print $7}' access.log | sort -u)
  assert "statuts.txt" cmp -s <(sed "$norm" statuts.txt 2>/dev/null) <(awk '{print $9}' access.log | sort | uniq -c | sed "$norm")
  assert_eq "octets.txt" "$(awk '{s+=$10} END{print s}' access.log)" "$(tr -d ' \n' < octets.txt 2>/dev/null)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  ls /etc /dossier-inexistant > sortie.txt 2> erreurs.txt
  ls /etc /dossier-inexistant > tout.txt 2>&1
  cat > bienvenue.txt << EOF
Bonjour $(whoami)
Fin du message
EOF
  awk '$9 == 404' access.log > erreurs_404.txt
  awk '$9 == 404' access.log | wc -l > nb_404.txt
  awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -3 > top_ips.txt
  awk '{print $7}' access.log | sort -u > urls.txt
  awk '{print $9}' access.log | sort | uniq -c > statuts.txt
  awk '{s+=$10} END{print s}' access.log > octets.txt
}

lab_main "$@"
