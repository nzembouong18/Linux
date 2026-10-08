#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=03

lab_setup() {
  local v="$LAB_DIR/vrac"
  rm -rf "$LAB_DIR/range" "$LAB_DIR/sauvegarde" "$LAB_DIR/rapport.txt" "$v"
  mkdir -p "$v/sous dossier"
  echo "photo" > "$v/vacances été.jpg"
  head -c 4000 /dev/zero > "$v/plage.jpg"
  head -c 1500 /dev/zero > "$v/logo.png"
  echo "contrat" > "$v/contrat final.pdf"
  head -c 70000 /dev/zero > "$v/manuel.pdf"
  echo "note" > "$v/note-2024.txt"
  echo "todo" > "$v/todo.txt"
  printf 'INFO ok\nERROR boom\n' > "$v/app.log"
  printf 'ERROR a\nERROR b\n' > "$v/erreurs.log"
  echo "x" > "$v/cache.tmp"
  echo "y" > "$v/sous dossier/brouillon.tmp"
  echo "z" > "$v/sous dossier/important.cfg"
}

lab_check() {
  local L="$LAB_DIR"
  assert "dossiers images/documents/logs créés" test -d "$L/range/images" -a -d "$L/range/documents" -a -d "$L/range/logs"
  assert "images rangées (jpg+png)" test -f "$L/range/images/plage.jpg" -a -f "$L/range/images/vacances été.jpg" -a -f "$L/range/images/logo.png"
  assert "documents rangés (pdf+txt)" test -f "$L/range/documents/manuel.pdf" -a -f "$L/range/documents/contrat final.pdf" -a -f "$L/range/documents/note-2024.txt" -a -f "$L/range/documents/todo.txt"
  assert "logs rangés" test -f "$L/range/logs/app.log" -a -f "$L/range/logs/erreurs.log"
  assert "vrac ne contient plus de jpg/png/pdf/txt/log" test -z "$(find "$L/vrac" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.pdf' -o -name '*.txt' -o -name '*.log' \))"
  assert "tous les .tmp supprimés" test -z "$(find "$L/vrac" -name '*.tmp')"
  assert "fichier non .tmp conservé (important.cfg)" test -f "$L/vrac/sous dossier/important.cfg"
  assert "courant.txt est un lien symbolique vers note-2024.txt" test "$(readlink "$L/range/documents/courant.txt")" = "note-2024.txt"
  assert "dernier.log est un lien DUR de app.log" test "$L/range/logs/dernier.log" -ef "$L/range/logs/app.log" -a ! -L "$L/range/logs/dernier.log"
  assert "sauvegarde contient une copie de range" test -f "$L/sauvegarde/documents/manuel.pdf"
  assert "sauvegarde préserve les dates (-a)" test "$(stat -c %Y "$L/range/documents/manuel.pdf" 2>/dev/null || echo a)" = "$(stat -c %Y "$L/sauvegarde/documents/manuel.pdf" 2>/dev/null || echo b)"
  local r="$L/rapport.txt"; get() { grep -E "^$1=" "$r" 2>/dev/null | head -1 | cut -d= -f2-; }
  assert_eq "PLUS_GROS" "manuel.pdf" "$(get PLUS_GROS)"
  assert_eq "NB_LOGS" "2" "$(get NB_LOGS)"
  local sz; sz=$(du -sb "$L/range" 2>/dev/null | cut -f1)
  assert_eq "ESPACE (octets)" "$sz" "$(get ESPACE)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  mkdir -p range/{images,documents,logs}
  mv vrac/*.jpg vrac/*.png range/images/
  mv vrac/*.pdf vrac/*.txt range/documents/
  mv vrac/*.log range/logs/
  find vrac -name '*.tmp' -delete
  ln -s note-2024.txt range/documents/courant.txt
  ln range/logs/app.log range/logs/dernier.log
  cp -a range sauvegarde
  {
    echo "PLUS_GROS=$(find range -type f -printf '%s %f\n' | sort -rn | head -1 | cut -d' ' -f2-)"
    echo "NB_LOGS=$(find range/logs -type f -name '*.log' ! -name dernier.log | wc -l)"
    echo "ESPACE=$(du -sb range | cut -f1)"
  } > rapport.txt
}

lab_main "$@"
