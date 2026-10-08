#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
LAB_ID=02

lab_setup() {
  local a="$LAB_DIR/arbre"
  rm -rf "$a"
  mkdir -p "$a"/docs/manuel "$a"/docs/img "$a"/src/app/core/engine "$a"/src/lib "$a"/bin "$a"/.cache
  echo "Chapitre 1" > "$a/docs/manuel/ch1.txt"
  echo "Chapitre 2" > "$a/docs/manuel/ch2.txt"
  head -c 2048  /dev/zero > "$a/docs/img/logo.png"
  head -c 90000 /dev/zero > "$a/docs/img/banniere.png"
  echo 'int main(){}' > "$a/src/app/main.c"
  echo 'void util(){}' > "$a/src/app/util.c"
  head -c 5120 /dev/zero > "$a/src/app/core/engine/moteur.bin"
  echo "libtruc" > "$a/src/lib/libtruc.a"
  head -c 300000 /dev/zero > "$a/.cache/gros_cache.dat"
  echo "secret" > "$a/.secret"
  echo "README" > "$a/README.md"
  echo '#!/bin/sh' > "$a/bin/lancer.sh"
  ln -s ../src/app/main.c "$a/bin/lancer"
  # La « bonne réponse » pour GROS est cachée dans .cache : le plus gros fichier est gros_cache.dat
}

lab_check() {
  local a="$LAB_DIR/arbre" r="$LAB_DIR/reponses.txt"
  get() { grep -E "^$1=" "$r" 2>/dev/null | head -1 | cut -d= -f2-; }
  assert "reponses.txt existe" test -f "$r"
  local deep; deep=$(find "$a" -type d | awk -F/ '{print NF, $0}' | sort -rn | head -1 | cut -d' ' -f2-)
  assert_eq "PROFOND" "$deep" "$(get PROFOND)"
  assert_eq "NB_FICHIERS" "$(find "$a" -type f | wc -l)" "$(get NB_FICHIERS)"
  assert_eq "GROS" "gros_cache.dat" "$(get GROS)"
  assert_eq "CACHES" "$(find "$a" -mindepth 1 -maxdepth 1 -name '.*' | wc -l)" "$(get CACHES)"
  assert_eq "RELATIF" "../../docs/manuel" "$(get RELATIF)"
  assert_eq "LIEN" "$(readlink "$a/bin/lancer")" "$(get LIEN)"
}

lab_solve() {
  cd "$LAB_DIR" || return 1
  {
    echo "PROFOND=$(find "$PWD/arbre" -type d | awk -F/ '{print NF, $0}' | sort -rn | head -1 | cut -d' ' -f2-)"
    echo "NB_FICHIERS=$(find arbre -type f | wc -l)"
    echo "GROS=$(find arbre -type f -printf '%s %f\n' | sort -rn | head -1 | cut -d' ' -f2-)"
    echo "CACHES=$(find arbre -mindepth 1 -maxdepth 1 -name '.*' | wc -l)"
    echo "RELATIF=../../docs/manuel"
    echo "LIEN=$(readlink arbre/bin/lancer)"
  } > reponses.txt
}

lab_main "$@"
